#!/usr/bin/env nu

# ==================================================================================================
# Notification Stub
# ==================================================================================================
# Stands in for the notification backend in project-notify and notify.sh tests. Each invocation
# appends its argument list as a JSON line to `$env.NOTIFY_LOG`.
# ==================================================================================================

def --wrapped main [...args: string] {
  $args | to json --raw | append "" | str join "\n" | save --append $env.NOTIFY_LOG
}
