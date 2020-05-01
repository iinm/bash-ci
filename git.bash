#!/usr/bin/env bash

has_remote_update() {
  local remote branch
  remote="origin"
  branch=$(git rev-parse --abbrev-ref HEAD)

  while true; do
    if test "$#" -eq 0; then
      break
    fi
    case "$1" in
      --help )
        echo "Usage: ${FUNCNAME[0]} [--remote REMOTE (default: origin)] [--branch BRANCH (default: current branch)]"
        return 0
        ;;
      --remote ) remote=$2; shift 2 ;;
      --branch ) branch=$2; shift 2 ;;
      * ) break ;;
    esac
  done

  local remote_sha
  remote_sha="$(git ls-remote "$remote" "$branch" | awk '{ print $1 }')"
  if test -z "$remote_sha"; then
    echo "error: $remote/$branch is not found" >&2
    return 1
  fi

  local_sha="$(git rev-parse "$branch" || echo '')"
  test "$remote_sha" != "$local_sha"
}


if test "${BASH_SOURCE[0]}" = "$0"; then
  set -eu -o pipefail
  "$@"
fi
