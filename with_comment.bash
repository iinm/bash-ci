#!/usr/bin/env bash

: "${GITLAB_BASE_URL:?}"
: "${GITLAB_PROJECT_ID:?}"
: "${GITLAB_PRIVATE_TOKEN:?}"
: "${MERGE_REQUEST_IID:?}"
: "${COMMENT_ON_START:?}"
: "${COMMENT_ON_SUCCESS:?}"
: "${COMMENT_ON_FAIL:?}"

comment() {
  curl --silent -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -d "body=${1?}" \
    "$GITLAB_BASE_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests/$MERGE_REQUEST_IID/notes"
}

on_exit() {
  exit_code="$?"
  if test "$exit_code" = "0"; then
    comment "$COMMENT_ON_SUCCESS" || true
  else
    comment "$COMMENT_ON_FAIL" || true
  fi
  return "$exit_code"
}

trap on_exit EXIT INT TERM

comment "$COMMENT_ON_START"

"$@"
