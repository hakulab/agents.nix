#!/usr/bin/env bash

# ==================================================================================================
# Antigravity CLI Auth Profile Loader
# ==================================================================================================

set -euo pipefail

unset @profileEnvVars@
__agy_profile_mode=""
__agy_profile_model=""
__agy_profile_settings_file=""
__agy_settings=""

__agy_profile="@stateDir@/active-profile"
if [ -f "$__agy_profile" ]; then
  # shellcheck disable=SC1090  # dynamic profile path resolved at runtime
  . "$__agy_profile"
else
  echo "agy: no active auth profile at ${__agy_profile}" >&2
  exit 1
fi

if [ "$__agy_profile_mode" = "api" ]; then
  # shellcheck disable=SC1091  # store path substituted by Nix
  . "@apiArgsScript@"
  validate_agy_api_args "$@"
fi

if [ -n "$__agy_profile_settings_file" ]; then
  __agy_user_settings="$HOME/.gemini/antigravity-cli/settings.json"
  if [ -f "$__agy_user_settings" ]; then
    if ! __agy_settings="$(
      # shellcheck disable=SC2016  # jq filter variables
      @jq@ -ce \
        --slurpfile managed "$__agy_profile_settings_file" \
        '
          .permissions as $saved
          | $managed[0]
          | .permissions.allow += ($saved.allow // [])
          | .permissions.ask += ($saved.ask // [])
          | .permissions.deny += ($saved.deny // [])
        ' \
        "$__agy_user_settings"
    )"; then
      echo "agy: could not load saved permission rules from settings.json" >&2
      exit 1
    fi
  else
    if ! __agy_settings="$(@jq@ -ce . "$__agy_profile_settings_file")"; then
      echo "agy: could not load managed settings" >&2
      exit 1
    fi
  fi
fi

if [ -n "$__agy_settings" ] && [ -n "$__agy_profile_model" ]; then
  set -- --settings "$__agy_settings" --model "$__agy_profile_model" "$@"
fi
