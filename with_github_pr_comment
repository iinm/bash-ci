#!/usr/bin/env bash

set -eu -o pipefail

help() {
  cat << 'HELP'
Usage: with_github_pr_comment --id PULL_REQUEST_id
                              [--comment-on-start COMMENT] [--comment-on-cancel COMMENT]
                              [--comment-on-success COMMENT] [--comment-on-fail COMMENT]
                              COMMAND

Run command and post comment on pull request
HELP
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=github.bash
source "$script_dir/github.bash"

while test "$#" -gt 0; do
  case "$1" in
    --help               ) help; exit 0 ;;
    --id                ) id=$2; shift 2 ;;
    --comment-on-start   ) comment_on_start=$2; shift 2 ;;
    --comment-on-cancel  ) comment_on_cancel=$2; shift 2 ;;
    --comment-on-success ) comment_on_success=$2; shift 2 ;;
    --comment-on-fail    ) comment_on_fail=$2; shift 2 ;;
    --*                  ) echo "error: unknown option $1"; exit 1 ;;
    *                    ) break ;;
  esac
done

require_envs
: "${id?}"
: "${comment_on_start:=}"
: "${comment_on_cancel:=}"
: "${comment_on_success:=}"
: "${comment_on_fail:=}"

if test "$#" -eq 0; then
  help >&2
  exit 1
fi

comment_if_not_empty() {
  local comment="${1?}"
  if test -n "$comment"; then
    comment_on_pull_request --id "$id" --comment "$comment"
  fi
}

on_exit() {
  local exit_status="$?"
  if test "$exit_status" -eq 0; then
    comment_if_not_empty "$comment_on_success"
  else
    comment_if_not_empty "$comment_on_fail"
  fi
  return "$exit_status"
}

on_cancel() {
  local exit_status=0
  trap -- EXIT
  kill -s HUP "$pid"
  wait "$pid" || exit_status=$?
  comment_if_not_empty "$comment_on_cancel"
  return "$exit_status"
}

trap 'on_exit' EXIT
trap 'on_cancel' HUP INT QUIT TERM

comment_if_not_empty "$comment_on_start"

"$@" &
pid=$!
wait "$pid"
