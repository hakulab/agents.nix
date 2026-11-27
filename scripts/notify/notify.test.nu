#!/usr/bin/env nu

# ==================================================================================================
# Cross-Platform Notification Helper Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const NOTIFY_NU = ($SCRIPT_DIR | path join "notify.nu")

# Read all JSONL invocations recorded by the notify stub.
def read-calls [log: path]: nothing -> list<list<string>> {
  if not ($log | path exists) {
    return []
  }

  open --raw $log
  | lines
  | where {|line| $line | is-not-empty }
  | each {|line| $line | from json }
}

# Run `notify.nu` for `$platform` with its backend overridden to the notify stub.
def run-notify [
  platform: string
  bin_var: string
  args: list<string>
]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "notify.jsonl")
  let stub = ($env.NU_TEST_STUBS | path join "notify")

  let env_vars = (
    {
      NOTIFY_LOG: $log
      NOTIFY_PLATFORM: $platform
    }
    | upsert $bin_var $stub
  )

  let run = with-env $env_vars {
    run-script $NOTIFY_NU ...$args
  }

  {
    run: $run
    calls: (read-calls $log)
  }
}

# --------------------------------------------------------------------------------------------------
# Platform dispatch
# --------------------------------------------------------------------------------------------------

def "test notify.nu forwards app and icon flags to toasty on WSL" [] {
  let result = (
    run-notify "wsl" "TOASTY_BIN" [
      "Claude Code"
      "[demo] Response complete"
      --app
      "claude"
      --icon
      "/tmp/icon.png"
    ]
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["[demo] Response complete" "-t" "Claude Code" "--app" "claude" "--icon" "/tmp/icon.png"]
  ]
}

def "test notify.nu omits empty app and icon flags on WSL" [] {
  let result = (run-notify "wsl" "TOASTY_BIN" ["Claude Code" "[demo] Question asked"])

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["[demo] Question asked" "-t" "Claude Code"]
  ]
}

def "test notify.nu forwards app and icon flags to notify-send on Linux" [] {
  let result = (
    run-notify "linux" "NOTIFY_SEND_BIN" [
      "Codex"
      "[demo] Response complete"
      --app
      "codex"
      --icon
      "dialog-information"
    ]
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["-a" "codex" "-i" "dialog-information" "Codex" "[demo] Response complete"]
  ]
}

def "test notify.nu passes title and body via argv to osascript on macOS" [] {
  let result = (
    run-notify "darwin" "OSASCRIPT_BIN" [
      'Title "with" quotes'
      "Body with 'single' and $(cmd)"
      --app
      "claude"
    ]
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    [
      "-e"
      "on run argv"
      "-e"
      'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"'
      "-e"
      "end run"
      "--"
      'Title "with" quotes'
      "Body with 'single' and $(cmd)"
    ]
  ]
}

def "test notify.nu defaults title when called with no arguments" [] {
  let result = (run-notify "linux" "NOTIFY_SEND_BIN" [])

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["Notification" ""]
  ]
}

def "test notify.nu exits cleanly when notifier binary is missing" [] {
  let run = with-env {
    NOTIFY_PLATFORM: "linux"
    NOTIFY_SEND_BIN: "/nonexistent/notify-send"
  } {
    run-script $NOTIFY_NU "Claude Code" "[demo] Done"
  }

  assert equal $run.exit_code 0 $run.stderr
}
