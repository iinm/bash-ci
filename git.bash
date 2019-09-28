#!/usr/bin/env bash

has_remote_update() {
  remote="${1?}"  # e.g. origin
  branch="${2?}"

  remote_sha="$(git ls-remote "$remote" "$branch" | awk '{ print $1 }')"
  if test -z "$remote_sha"; then
    echo "error: $remote/$branch is not found" >&2
    return 1
  fi

  local_sha="$(git rev-parse "$branch" || echo '')"
  test "$remote_sha" != "$local_sha"
}
