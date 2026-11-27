#!/usr/bin/env nu

# ==================================================================================================
# Cross-Platform Notification Helper
# ==================================================================================================
# Dispatches desktop notifications across WSL (toasty.exe), Linux (notify-send), and macOS
# (osascript), forwarding optional --app and --icon flags where supported.
# ==================================================================================================

# Return the non-empty environment variable `$name`, or `$fallback` when unset or empty.
def env-or-default [name: string, fallback: string]: nothing -> string {
  let value = ($env | get -o $name | default "")
  if ($value | is-not-empty) {
    $value
  } else {
    $fallback
  }
}

# Detect the notification platform (`wsl`, `linux`, `darwin`, or `unknown`), honoring
# `NOTIFY_PLATFORM` when set.
def detect-platform []: nothing -> string {
  let override = (env-or-default "NOTIFY_PLATFORM" "")
  if ($override | is-not-empty) {
    return $override
  }

  match $nu.os-info.name {
    "macos" => "darwin"
    "linux" => {
      let proc_version = try {
        open --raw "/proc/version" | into string
      } catch {
        ""
      }
      if ($proc_version | str downcase | str contains "microsoft") {
        "wsl"
      } else {
        "linux"
      }
    }
    _ => "unknown"
  }
}

# Invoke the platform notifier best-effort, ignoring missing binaries and nonzero exits.
def run-notifier [bin: string, args: list<string>]: nothing -> nothing {
  try {
    ^$bin ...$args | complete | ignore
  } catch {
    null
  }
  null
}

# Send a desktop notification on WSL, Linux, or macOS.
def main [
  title: string = "Notification" # Notification title
  body: string = "" # Notification body
  --app: string = "" # Assistant preset or application name (e.g. claude, codex)
  --icon: string = "" # Custom icon path or theme icon name
] {
  match (detect-platform) {
    "wsl" => {
      mut args: list<string> = if ($body | is-not-empty) {
        [$body -t $title]
      } else {
        [$title]
      }
      if ($app | is-not-empty) {
        $args = ($args | append [--app $app])
      }
      if ($icon | is-not-empty) {
        $args = ($args | append [--icon $icon])
      }

      run-notifier (env-or-default "TOASTY_BIN" "toasty.exe") $args
    }

    "linux" => {
      mut args: list<string> = []
      if ($app | is-not-empty) {
        $args = ($args | append [-a $app])
      }
      if ($icon | is-not-empty) {
        $args = ($args | append [-i $icon])
      }
      $args = ($args | append [-- $title $body])

      run-notifier (env-or-default "NOTIFY_SEND_BIN" "notify-send") $args
    }

    "darwin" => {
      let args = [
        -e
        "on run argv"
        -e
        'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"'
        -e
        "end run"
        --
        $title
        $body
      ]

      run-notifier (env-or-default "OSASCRIPT_BIN" "osascript") $args
    }

    _ => null
  }
}
