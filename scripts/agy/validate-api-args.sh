#!/usr/bin/env bash

# ==================================================================================================
# Antigravity CLI API-Key Launch Arguments
# ==================================================================================================

# Fail closed on managed-settings overrides and ACP subcommands without tracking every global flag.
# Only a leading prompt flag is safe to consume because an earlier value flag could consume a later
# -p/-i as its own argument and leave a following acp subcommand unchecked.
validate_agy_api_args() {
  if [ "$#" -eq 2 ] && [ "$1" = help ] && [ "$2" = acp ]; then
    return 0
  fi

  case "${1:-}" in
    -p | -i | --print | -print | --prompt | -prompt | --prompt-interactive | -prompt-interactive)
      [ "$#" -ge 2 ] || return 0
      shift 2
      ;;
  esac

  local arg
  for arg; do
    case "$arg" in
      --settings | --settings=* | -settings | -settings=*)
        echo "agy: the API-key profile manages --settings. Use native settings.json for preferences." >&2
        return 1
        ;;
      acp)
        echo "agy: ACP requires the official profile. Run agy-switch official first." >&2
        return 1
        ;;
    esac
  done
}
