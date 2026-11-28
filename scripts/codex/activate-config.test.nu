#!/usr/bin/env nu

# ==================================================================================================
# Codex Config Activation Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "activate-config.nu")

def command [command: string, extra: record = {}]: nothing -> record {
  {
    type: "command"
    command: $command
  }
  | merge $extra
}

def "test activation records golden hook hashes and keeps other state" [] {
  let dir = (mktemp --directory | path expand --strict)
  let target = ($dir | path join "config.toml")
  let config_file = ($dir | path join "activation.json")
  let key = {|event: string, group: int, handler: int| $"($target):($event):($group):($handler)" }
  let project_key = "/repo/.codex/config.toml:stop:0:0"

  let prior_state = {
    (do $key stop 0 0): {
      enabled: false
      trusted_hash: "sha256:stale"
    }
    $project_key: {trusted_hash: "sha256:project"}
  }
  {hooks: {state: $prior_state}}
  | to toml
  | save $target
  let edits = "Edit|Write"
  {
    configDir: $dir
    activeProfile: ($dir | path join "missing-profile")
    settings: {
      tools: {}
      mcp_servers: {}
      hooks: {
        PostToolUse: [
          {
            matcher: $edits
            hooks: [
              (command "/bin/format" {
                timeout: 120
                statusMessage: "Formatting edited files"
              })
            ]
          }
          {
            matcher: $edits
            hooks: [
              (command "/bin/gate" {
                timeout: 100
                statusMessage: "Checking"
              })
            ]
          }
          {
            hooks: [(command "/bin/status working")]
          }
        ]
        SessionStart: [
          {
            matcher: "compact"
            hooks: [
              (command "/bin/restore" {
                timeout: 10
                statusMessage: "Restoring context"
              })
            ]
          }
          {
            matcher: "startup|resume|clear"
            hooks: [(command "/bin/register")]
          }
        ]
        PermissionRequest: [
          {hooks: [(command "/bin/status waiting") (command "/bin/instant" {timeout: 0})]}
        ]
        SubagentStart: [{hooks: [(command "/bin/status working")]}]
        SubagentStop: [{hooks: [(command "/bin/status working")]}]
        UserPromptSubmit: [{hooks: [(command "/bin/status working")]}]
        SessionEnd: [{hooks: [(command "/bin/end" {timeout: 5})]}]
        Interrupt: [{hooks: [(command "/bin/interrupted") (command "/bin/abort" {timeout: 0})]}]
        Stop: [
          {
            matcher: "ignored"
            hooks: [(command "/bin/status done")]
          }
        ]
      }
    }
    keybindings: []
  }
  | to json
  | save $config_file

  let run = run-script $SCRIPT --config $config_file
  assert equal $run.exit_code 0 $run.stderr

  let trusted = (
    [
      ["interrupt" 0 0 "sha256:5e55f2d7ba9fe9bc2f9449637467516df7a6515d0c4d2d4f92dd8313796d20e4"]
      ["interrupt" 0 1 "sha256:5d6832087ad0ad90ac8bacb6ef2a558c565bb7d4d3969b94df0b715c05cd9dfd"]
      ["permission_request" 0 0 "sha256:88b1c694c14770423c7290cf89139e3a31c7c0a094cb23c32e75221357e54791"]
      ["permission_request" 0 1 "sha256:88304f35c7686a9c16dff3d1d0fcf522d05602cb13939b09ac8540ec55f000c1"]
      ["post_tool_use" 0 0 "sha256:ae611e91dacde798572294eea30350e2261cd767dfcb4d1657d30c9217d0bbda"]
      ["post_tool_use" 1 0 "sha256:21d718aef85523d6d1a3c123e1f8a9dc26fa6d879ac293697d02ea747639d1fc"]
      ["post_tool_use" 2 0 "sha256:61296deaabf04eafe4472d463221d416903ca8b89b4ff9a2a4af0a82c146565b"]
      ["session_end" 0 0 "sha256:1a2be0c709c51a7011e4a849b117dd1f04809857a259648f98ed7887dbbcba9a"]
      ["session_start" 0 0 "sha256:af8c3db47468b115b8fc6b60f6d35afd11494f1a421bda876fb4fac6c7f958e1"]
      ["session_start" 1 0 "sha256:fcae088b8e23f03f9d0199109d6f6a1a15aaf95751d4ba8bd4344c987455a801"]
      ["stop" 0 0 "sha256:a48d48f3315c065473c178b65563ad0cc6da8b7098e06387a895937dc7ace2df"]
      ["subagent_start" 0 0 "sha256:83089946ab1220d223a4a1381d5ac295cb12d309a638c02df0134697a9230493"]
      ["subagent_stop" 0 0 "sha256:59f4b73a2411229cbc36b221441799f36622a486a2f069b3fcd5440101d257ff"]
      ["user_prompt_submit" 0 0 "sha256:2177cc88452c247631f10c1985d043f1a9c5c8c1b90dc6f56d429b3b7938fbd5"]
    ]
    | reduce --fold {} {|row, acc|
      $acc | insert ([(do $key $row.0 $row.1 $row.2)] | into cell-path) {trusted_hash: $row.3}
    }
  )
  assert equal (open $target | get hooks.state) (
    $trusted
    | update ([(do $key stop 0 0)] | into cell-path) { insert enabled false }
    | insert ([$project_key] | into cell-path) {trusted_hash: "sha256:project"}
  )
}

def "test activation trusts command hooks with normalized context limits" [] {
  let dir = (mktemp --directory | path expand --strict)
  let target = ($dir | path join "config.toml")
  let config_file = ($dir | path join "activation.json")
  let emit = (command "/bin/emit")
  let limited = (command "/bin/emit" {additionalContextLimit: 20000})
  let settings = {
    tools: {}
    mcp_servers: {}
    hooks: {
      PreToolUse: [{hooks: [$limited]}]
      PostToolUse: [
        {
          hooks: [
            $emit
            (command "/bin/emit" {additionalContextLimit: 2500})
            $limited
            (command "/bin/emit" {additionalContextLimit: 0})
          ]
        }
      ]
      SessionStart: [{hooks: [$limited]}]
      UserPromptSubmit: [{hooks: [$limited]}]
      SubagentStart: [{hooks: [$limited]}]
      Stop: [{hooks: [$limited]}]
    }
  }
  {
    configDir: $dir
    activeProfile: ($dir | path join "missing-profile")
    settings: $settings
    keybindings: []
  }
  | to json
  | save $config_file

  let run = run-script $SCRIPT --config $config_file
  assert equal $run.exit_code 0 $run.stderr

  let trusted = (
    [
      ["pre_tool_use" 0 "58beef7f273a949865a2d68a3d63db562f7b2e22e31fe815d55d6ca2b6949556"]
      ["post_tool_use" 0 "342893e6672f62ef1d534c0c2c32d9662f8f9c1d04cc361b1574cd5bc9416249"]
      ["post_tool_use" 1 "342893e6672f62ef1d534c0c2c32d9662f8f9c1d04cc361b1574cd5bc9416249"]
      ["post_tool_use" 2 "5bf698c4d02ac75f9de80619be4727d5d9ba4241ead9021c89b6bcb1fd0b53ad"]
      ["post_tool_use" 3 "a9db263656220ffbe20a0955f56a94f4589a1ec5ec223d3d6d2021e461fee97f"]
      ["session_start" 0 "1eb62ee060c04911942150e54c63d9a65b4d01c0c9528ad059effe5840ffd22d"]
      ["user_prompt_submit" 0 "9b088d9ae2e241be6f5d1c86d11636a0c80ffe4e7507fc2c870fc7754317f82f"]
      ["subagent_start" 0 "9990a9112ce93580d000b248b276123dfb1c14892e379a47f5c6803b40d04bd5"]
      ["stop" 0 "942459e342f08f39c7d1b728a6901389247c1a8a0bf59998bb2dd64ef448666d"]
    ]
    | reduce --fold {} {|row, acc|
      let key = $"($target):($row.0):0:($row.1)"
      $acc | insert ([$key] | into cell-path) {trusted_hash: $"sha256:($row.2)"}
    }
  )
  let activated = open $target | get hooks
  assert equal $activated.state $trusted
  assert equal ($activated | reject state) $settings.hooks
}

def "test activation trusts hooks at the canonical config path" [] {
  for alias in [false true] {
    let dir = (mktemp --directory | path expand --strict)
    let canonical = ($dir | path join "config")
    let config_dir = if $alias {
      mkdir $canonical
      let link = ($dir | path join "alias")
      ^ln -s $canonical $link
      $link
    } else {
      $canonical
    }
    let config_file = ($dir | path join "activation.json")
    let keybindings = [
      {
        command: "hotkeyWindow"
        key: "Ctrl+Space"
      }
    ]
    {
      configDir: $config_dir
      activeProfile: ($dir | path join "missing-profile")
      settings: {
        tools: {}
        mcp_servers: {}
        hooks: {Stop: [{hooks: [(command "/bin/status done")]}]}
      }
      keybindings: $keybindings
    }
    | to json
    | save $config_file

    let run = run-script $SCRIPT --config $config_file
    assert equal $run.exit_code 0 $run.stderr

    let key = $"($canonical)/config.toml:stop:0:0"
    assert equal (open ($canonical | path join "config.toml") | get hooks.state) {
      $key: {
        trusted_hash: "sha256:a48d48f3315c065473c178b65563ad0cc6da8b7098e06387a895937dc7ace2df"
      }
    } $"symlinked config directory: ($alias)"
    assert equal (open ($canonical | path join "keybindings.json")) $keybindings
  }
}

def "test activation imports only profiles in the canonical config directory" [] {
  for case in [
    [configAlias profileAlias contained];
    [false false true]
    [true false true]
    [false true true]
    [true true false]
  ] {
    let dir = (mktemp --directory | path expand --strict)
    let canonical = ($dir | path join "config")
    let alias = ($dir | path join "alias")
    mkdir $canonical
    ^ln -s $canonical $alias
    let profile_dir = if $case.contained {
      if $case.profileAlias { $alias } else { $canonical }
    } else {
      $dir
    }
    let profile = ($profile_dir | path join "native-profile.toml")
    let state = {"/repo": {trust_level: "trusted"}}
    {projects: $state}
    | to toml
    | save $profile
    let active = ($dir | path join "active-profile")
    ^ln -s $profile $active
    let config_file = ($dir | path join "activation.json")
    {
      configDir: (if $case.configAlias { $alias } else { $canonical })
      activeProfile: $active
      settings: {
        tools: {}
        mcp_servers: {}
        hooks: {}
      }
      keybindings: []
    }
    | to json
    | save $config_file

    let run = run-script $SCRIPT --config $config_file
    assert equal $run.exit_code 0 $run.stderr

    let projects = (open ($canonical | path join "config.toml") | get -o projects)
    assert equal $projects (if $case.contained { $state } else { null }) ($case | to nuon)
  }
}
