#!/usr/bin/env bash

# ==================================================================================================
# Antigravity CLI API-Key Launch Arguments
# ==================================================================================================

# Global flags with a separate value can precede the subcommand.
validate_agy_api_args() {
  local flag
  while [ "$#" -gt 0 ]; do
    flag=$1
    if [[ $flag == -[!-]?* ]]; then
      flag="-$flag"
    fi

    case "$flag" in
      --)
        shift
        break
        ;;
      --settings | --settings=*)
        echo "agy: the API-key profile manages --settings. Use native settings.json for preferences." >&2
        return 1
        ;;
      --add-dir | --agent | --conversation | -r | --resume | --effort | --input-format | \
        --json-schema | --log-file | --mode | --model | --output-format | -p | --print | \
        --prompt | -i | --prompt-interactive | --print-timeout | --project)
        [ "$#" -ge 2 ] || return 0
        shift 2
        ;;
      -*) shift ;;
      *) break ;;
    esac
  done

  if [ "${1:-}" = acp ]; then
    echo "agy: ACP requires the official profile. Run agy-switch official first." >&2
    return 1
  fi
}
