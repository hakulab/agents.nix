#!/usr/bin/env bash

# ==================================================================================================
# Antigravity CLI Auth Profile Loader
# ==================================================================================================

set -euo pipefail

unset @profileEnvVars@

__agy_profile="@stateDir@/active-profile"
if [ -f "$__agy_profile" ]; then
  # shellcheck disable=SC1090  # dynamic profile path resolved at runtime
  . "$__agy_profile"
else
  echo "agy: no active auth profile at ${__agy_profile}" >&2
  exit 1
fi
