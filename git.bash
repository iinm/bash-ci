#!/usr/bin/env bash

log() {
  echo "$(date "+%Y-%m-%d %H:%M:%S")" "$@" >&2
}


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


hook_push() {
  local logdir hooks
  while test "$#" -gt 0; do
    case "$1" in
      --help )
        echo "Usage: git ls-remote REPOSIITORY | ${FUNCNAME[0]} --logdir DIR --hooks LTSV_FILE"
        return 0
        ;;
      --logdir ) logdir=$2; shift 2 ;;
      --hooks  ) hooks=$2; shift 2; break ;;
      *        ) echo "unknown argument $1"; return 1 ;;
    esac
  done

  : "${logdir?}"
  : "${hooks?}"

  local exit_status=0
  while IFS=$'\t' read -r sha ref; do
    local hook_id refs_pattern cmd
    while read -r line; do
      hook_id=$(echo "$line" | value_from_ltsv "hook_id")
      refs_pattern=$(echo "$line" | value_from_ltsv "refs_pattern")
      cmd=$(echo "$line" | value_from_ltsv "cmd")

      if ! (grep -qE "$refs_pattern" <<< "$ref"); then
        continue
      fi

      log "($hook_id) hooked $ref"
      commit_sha_short="${sha:0:7}"
      log_file="$logdir/${hook_id}.${commit_sha_short}.log"

      if test -f "$log_file"; then
        log "=> skip; log exists $log_file"
        continue
      fi

      mkdir -p "$(dirname "$log_file")"
      if env REF="$ref" COMMIT_SHA="$sha" bash -ue -o pipefail -c "$cmd" &> "$log_file"; then
        log "=> success; $log_file"
      else
        exit_status=$?
        log "=> failed; $log_file"
      fi
    done < "$hooks"
  done

  return "$exit_status"
}

value_from_ltsv() {
  key="${1?}"
  sed -E "s/(^|.+	)${key}:([^	]*).*/\2/"
}


if test "${BASH_SOURCE[0]}" = "$0"; then
  set -eu -o pipefail
  "$@"
fi
