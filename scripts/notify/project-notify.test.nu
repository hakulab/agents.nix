#!/usr/bin/env nu

# ==================================================================================================
# Project-Scoped Notification Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const PROJECT_NOTIFY = ($SCRIPT_DIR | path join "project-notify.nu")

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

# Write a list of transcript records to a JSONL file and return its path.
def write-transcript [dir: path, entries: list<record>]: nothing -> path {
  let path = ($dir | path join "transcript.jsonl")
  $entries
  | each {|entry| $entry | to json --raw }
  | str join "\n"
  | save --force $path
  $path
}

# Run `project-notify.nu` with the notify stub and return `{run, calls}`.
def run-project-notify [
  args: list<string>
  --stdin-text: string = ""
]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "notify.jsonl")
  let stub = ($env.NU_TEST_STUBS | path join "notify")

  let run = with-env {NOTIFY_LOG: $log} {
    $stdin_text | run-script $PROJECT_NOTIFY --notify $stub ...$args
  }

  {
    run: $run
    calls: (read-calls $log)
  }
}

# --------------------------------------------------------------------------------------------------
# project-notify.nu: argument and flag forwarding
# --------------------------------------------------------------------------------------------------

def "test project-notify forwards app and icon flags and uses payload cwd" [] {
  let payload = ({cwd: "/tmp/workspace/demo-repo"} | to json --raw)
  let result = (
    run-project-notify [
      "Codex"
      "Response complete"
      $payload
      --app
      "codex"
      --icon
      "/tmp/codex.png"
    ]
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["Codex" "[demo-repo] Response complete" "--app" "codex" "--icon" "/tmp/codex.png"]
  ]
}

def "test project-notify omits empty app and icon flags" [] {
  let payload = ({cwd: "/tmp/workspace/demo-repo"} | to json --raw)
  let result = (run-project-notify ["Claude Code" "Question asked" $payload])

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["Claude Code" "[demo-repo] Question asked"]
  ]
}

# --------------------------------------------------------------------------------------------------
# project-notify.nu: Claude Code Stop hook filtering
# --------------------------------------------------------------------------------------------------

def "test claude-stop skips when stop hook is active" [] {
  let event = (
    {
      cwd: "/tmp/workspace/demo-repo"
      stop_hook_active: true
    }
    | to json --raw
  )
  let result = (
    run-project-notify
      ["Claude Code" "Response complete" --app "claude" --claude-stop]
      --stdin-text $event
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls []
}

def "test claude-stop skips while background Agent task is unresolved" [] {
  let dir = (mktemp --directory)
  let transcript = (
    write-transcript $dir [
      {
        type: "assistant"
        message: {
          content: [
            {
              type: "tool_use"
              id: "tu_agent_1"
              name: "Agent"
              input: {
                description: "Run checks"
                run_in_background: true
              }
            }
          ]
        }
      }
      {
        type: "user"
        toolUseResult: {
          isAsync: true
          status: "async_launched"
          agentId: "agent_abc123"
        }
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_agent_1"
              content: "Async agent launched"
            }
          ]
        }
      }
    ]
  )
  let event = (
    {
      cwd: "/tmp/workspace/demo-repo"
      stop_hook_active: false
      transcript_path: $transcript
    }
    | to json --raw
  )
  let result = (
    run-project-notify
      ["Claude Code" "Response complete" --app "claude" --claude-stop]
      --stdin-text $event
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls []
}

def "test claude-stop skips while background Bash task is unresolved or only queued" [] {
  let dir = (mktemp --directory)
  let transcript = (
    write-transcript $dir [
      {
        type: "user"
        toolUseResult: {
          backgroundTaskId: "b_cmd_42"
        }
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_bash_1"
              content: "Command running in background"
            }
          ]
        }
      }
      {
        type: "queue-operation"
        operation: "enqueue"
        content: "<task-notification><task-id>b_cmd_42</task-id><status>completed</status></task-notification>"
      }
    ]
  )
  let event = (
    {
      cwd: "/tmp/workspace/demo-repo"
      stop_hook_active: false
      transcript_path: $transcript
    }
    | to json --raw
  )
  let result = (
    run-project-notify
      ["Claude Code" "Response complete" --app "claude" --claude-stop]
      --stdin-text $event
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls []
}

def "test claude-stop notifies once all background tasks resolve" [] {
  let dir = (mktemp --directory)
  let transcript = (
    write-transcript $dir [
      {
        type: "user"
        toolUseResult: {
          isAsync: true
          status: "async_launched"
          agentId: "agent_1"
        }
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_1"
              content: "launched"
            }
          ]
        }
      }
      {
        type: "user"
        toolUseResult: {
          backgroundTaskId: "b_2"
        }
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_2"
              content: "running"
            }
          ]
        }
      }
      {
        type: "user"
        message: {
          content: "<task-notification><task-id>agent_1</task-id><tool-use-id>tu_1</tool-use-id><status>completed</status></task-notification>"
        }
      }
      {
        type: "user"
        message: {
          content: "<task-notification><task-id>b_2</task-id><status>completed</status></task-notification>"
        }
      }
    ]
  )
  let event = (
    {
      cwd: "/tmp/workspace/demo-repo"
      stop_hook_active: false
      transcript_path: $transcript
    }
    | to json --raw
  )
  let result = (
    run-project-notify
      ["Claude Code" "Response complete" --app "claude" --claude-stop]
      --stdin-text $event
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["Claude Code" "[demo-repo] Response complete" "--app" "claude"]
  ]
}

def "test claude-stop notifies when background launch fails or TaskStop resolves it" [] {
  let dir = (mktemp --directory)
  let transcript = (
    write-transcript $dir [
      {
        type: "assistant"
        message: {
          content: [
            {
              type: "tool_use"
              id: "tu_err"
              name: "Bash"
              input: {
                command: "sleep 1"
                run_in_background: true
              }
            }
          ]
        }
      }
      {
        type: "user"
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_err"
              is_error: true
              content: "denied"
            }
          ]
        }
      }
      {
        type: "user"
        toolUseResult: {
          backgroundTaskId: "b_stopped"
        }
        message: {
          content: [
            {
              type: "tool_result"
              tool_use_id: "tu_stop"
              content: "running"
            }
          ]
        }
      }
      {
        type: "assistant"
        message: {
          content: [
            {
              type: "tool_use"
              id: "tu_task_stop"
              name: "TaskStop"
              input: {
                task_id: "b_stopped"
              }
            }
          ]
        }
      }
    ]
  )
  let event = (
    {
      cwd: "/tmp/workspace/demo-repo"
      stop_hook_active: false
      transcript_path: $transcript
    }
    | to json --raw
  )
  let result = (
    run-project-notify
      ["Claude Code" "Response complete" --app "claude" --claude-stop]
      --stdin-text $event
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.calls [
    ["Claude Code" "[demo-repo] Response complete" "--app" "claude"]
  ]
}
