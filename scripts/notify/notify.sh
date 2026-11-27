#!/usr/bin/env bash

# ==================================================================================================
# Cross-Platform Notification Helper
# ==================================================================================================
# Dispatches desktop notifications across WSL (toasty.exe), Linux (notify-send), and macOS
# (osascript), forwarding optional --app and --icon flags where supported.
# ==================================================================================================

set -euo pipefail

app=""
icon=""
positional=()

while (($# > 0)); do
  case "$1" in
    --app)
      if (($# < 2)); then
        printf 'notify: --app requires a value\n' >&2
        exit 2
      fi
      app="$2"
      shift 2
      ;;
    --app=*)
      app="${1#--app=}"
      shift
      ;;
    --icon)
      if (($# < 2)); then
        printf 'notify: --icon requires a value\n' >&2
        exit 2
      fi
      icon="$2"
      shift 2
      ;;
    --icon=*)
      icon="${1#--icon=}"
      shift
      ;;
    --)
      shift
      positional+=("$@")
      break
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

title="${positional[0]:-Notification}"
body="${positional[1]:-}"

detect_platform() {
  if [[ -n "${NOTIFY_PLATFORM:-}" ]]; then
    printf '%s\n' "$NOTIFY_PLATFORM"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      printf 'darwin\n'
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        printf 'wsl\n'
      else
        printf 'linux\n'
      fi
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

case "$(detect_platform)" in
  wsl)
    args=("$body" -t "$title")
    if [[ -n "$app" ]]; then
      args+=(--app "$app")
    fi
    if [[ -n "$icon" ]]; then
      args+=(--icon "$icon")
    fi
    "${TOASTY_BIN:-toasty.exe}" "${args[@]}" 2>/dev/null || true
    ;;
  linux)
    args=()
    if [[ -n "$app" ]]; then
      args+=(-a "$app")
    fi
    if [[ -n "$icon" ]]; then
      args+=(-i "$icon")
    fi
    args+=("$title" "$body")
    "${NOTIFY_SEND_BIN:-notify-send}" "${args[@]}" 2>/dev/null || true
    ;;
  darwin)
    "${OSASCRIPT_BIN:-osascript}" \
      -e 'on run argv' \
      -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' \
      -e 'end run' \
      -- "$title" "$body" 2>/dev/null || true
    ;;
esac
