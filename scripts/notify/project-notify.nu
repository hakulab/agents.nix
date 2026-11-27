#!/usr/bin/env nu

# ==================================================================================================
# Project-Scoped Notification
# ==================================================================================================

const SCRIPT_DIR = path self "."
const DEFAULT_NOTIFY = ($SCRIPT_DIR | path join "notify.nu")

# Parse a JSON string into a record, returning null when the input is empty or not a JSON object.
def parse-json-record [text: string]: nothing -> oneof<record, nothing> {
  if ($text | str trim | is-empty) {
    return null
  }

  # `from json` returns non-JSON text unchanged, so check the shape before reading a field.
  let parsed = try {
    $text | from json
  } catch {
    null
  }

  if ($parsed | describe | str starts-with "record") {
    $parsed
  } else {
    null
  }
}

# Extract a tag's inner text from a Claude Code `<task-notification>` XML payload.
def extract-xml-tag [text: string, tag: string]: nothing -> string {
  let pattern = ('<' + $tag + '>(?<value>[^<]+)</' + $tag + '>')
  let matches = ($text | parse --regex $pattern)
  if ($matches | is-empty) {
    ""
  } else {
    $matches | get 0.value | str trim
  }
}

# Remove every task from `$pending` matching a non-empty task id or tool-use id.
def resolve-task [
  pending: list<record>
  task_id: string
  tool_use_id: string
]: nothing -> list<record> {
  $pending | where {|task|
    let matches_task = ($task_id | is-not-empty) and ($task.task_id == $task_id)
    let matches_tool = ($tool_use_id | is-not-empty) and ($task.tool_use_id == $tool_use_id)
    not ($matches_task or $matches_tool)
  }
}

# Resolve any `<task-notification>` embedded in `$text` against `$pending`.
def resolve-notification-text [pending: list<record>, text: string]: nothing -> list<record> {
  if not ($text | str contains "<task-notification>") {
    return $pending
  }

  let task_id = (extract-xml-tag $text "task-id")
  let tool_use_id = (extract-xml-tag $text "tool-use-id")
  resolve-task $pending $task_id $tool_use_id
}

# Return true when `$value` is a Nushell list or table (JSON array of records).
def is-sequence [value: any]: nothing -> bool {
  let kind = ($value | describe)
  ($kind | str starts-with "list") or ($kind | str starts-with "table")
}

# Return true when a Claude Code JSONL transcript has unresolved background Agent or Bash tasks.
export def has-pending-background-tasks [transcript_path: path]: nothing -> bool {
  if not ($transcript_path | path exists) {
    return false
  }

  let raw = try {
    open --raw $transcript_path | into string
  } catch {
    return false
  }

  mut pending: list<record> = []

  for line in ($raw | lines) {
    let entry = (parse-json-record $line)
    if $entry == null {
      continue
    }

    let entry_type = ($entry | get -o type | default "")
    let content = ($entry | get -o message.content)
    let content_is_seq = (is-sequence $content)

    if $entry_type == "assistant" and $content_is_seq {
      for block in $content {
        if not ($block | describe | str starts-with "record") {
          continue
        }
        if ($block | get -o type | default "") != "tool_use" {
          continue
        }

        let name = ($block | get -o name | default "")
        if $name in ["Agent" "Bash"] {
          let is_bg = ($block | get -o input.run_in_background | default false)
          let tool_use_id = ($block | get -o id | default "")
          if $is_bg == true and ($tool_use_id | is-not-empty) {
            $pending = (
              $pending
              | append {
                task_id: ""
                tool_use_id: $tool_use_id
              }
            )
          }
        } else if $name == "TaskStop" {
          let stopped_id = ($block | get -o input.task_id | default "")
          if ($stopped_id | is-not-empty) {
            $pending = (resolve-task $pending $stopped_id "")
          }
        }
      }
      continue
    }

    if $entry_type != "user" {
      continue
    }

    let result = ($entry | get -o toolUseResult)
    if ($result | describe | str starts-with "record") {
      let is_async = (
        (($result | get -o isAsync | default false) == true)
        or (($result | get -o status | default "") == "async_launched")
      )
      let agent_id = if $is_async {
        $result | get -o agentId | default ""
      } else {
        ""
      }
      let bg_id = ($result | get -o backgroundTaskId | default "")
      let task_id = if ($agent_id | is-not-empty) { $agent_id } else { $bg_id }

      if ($task_id | is-not-empty) {
        let tool_use_id = if $content_is_seq {
          $content
          | where {|block|
            (
              ($block | describe | str starts-with "record")
              and (($block | get -o type | default "") == "tool_result")
            )
          }
          | first
          | default {}
          | get -o tool_use_id
          | default ""
        } else {
          ""
        }

        $pending = (
          resolve-task $pending $task_id $tool_use_id
          | append {
            task_id: $task_id
            tool_use_id: $tool_use_id
          }
        )
      }
    }

    if ($content | describe) == "string" {
      $pending = (resolve-notification-text $pending $content)
    } else if $content_is_seq {
      for block in $content {
        if not ($block | describe | str starts-with "record") {
          continue
        }
        if ($block | get -o type | default "") == "tool_result" {
          if ($block | get -o is_error | default false) == true {
            let err_tool_id = ($block | get -o tool_use_id | default "")
            $pending = (resolve-task $pending "" $err_tool_id)
          }

          let block_content = ($block | get -o content)
          if ($block_content | describe) == "string" {
            $pending = (resolve-notification-text $pending $block_content)
          }
        }
      }
    }
  }

  $pending | is-not-empty
}

# Notify with the title and message, prefixed by the project's directory name.
def main [
  title: string # Notification title
  message: string = "" # Notification body
  payload: string = "" # Event JSON whose cwd names the project in place of the working directory
  --notify: path # Wrapper-supplied command that shows the notification
  --app: string = "" # Assistant preset name forwarded to the notifier (e.g. claude, codex)
  --icon: string = "" # Custom icon path or name forwarded to the notifier
  --stdin # Read hook event JSON from stdin when payload is empty
  --claude-stop # Filter intermediate Claude Code Stop hook events before notifying (implies --stdin)
] {
  mut project = ($env.PWD | path basename)

  let raw_payload = if ($payload | is-not-empty) {
    $payload
  } else if $stdin or $claude_stop {
    try {
      ^cat
    } catch {
      ""
    }
  } else {
    ""
  }

  let parsed = (parse-json-record $raw_payload)
  if $parsed != null {
    let payload_cwd = ($parsed | get -o cwd | default "")
    if ($payload_cwd | is-not-empty) {
      $project = ($payload_cwd | path basename)
    }

    if $claude_stop {
      if ($parsed | get -o stop_hook_active | default false) == true {
        return
      }

      let transcript_path = ($parsed | get -o transcript_path | default "")
      if ($transcript_path | is-not-empty) and (has-pending-background-tasks $transcript_path) {
        return
      }
    }
  }

  mut args = [$title $"[($project)] ($message)"]
  if ($app | is-not-empty) {
    $args = ($args | append [--app $app])
  }
  if ($icon | is-not-empty) {
    $args = ($args | append [--icon $icon])
  }

  if $notify != null {
    ^$notify ...$args
  } else {
    ^$nu.current-exe $DEFAULT_NOTIFY ...$args
  }
}
