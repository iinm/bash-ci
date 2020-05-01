#!/usr/bin/env bash

log() {
  echo "$(date "+%Y-%m-%d %H:%M:%S")" "$@"
}

require_envs() {
  : "${GITLAB_BASE_URL:?}"
  : "${GITLAB_PRIVATE_TOKEN:?}"
  : "${GITLAB_PROJECT_ID:?}"
}

# https://docs.gitlab.com/ee/api/merge_requests.html#list-merge-requests
list_merge_requests() {
  require_envs
  local params=${1:-"state=opened&per_page=10000"}
  curl -Sfs -X GET "$GITLAB_BASE_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests?$params" -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN"
}

# https://docs.gitlab.com/ee/api/notes.html#create-new-merge-request-note
comment_on_merge_request() {
  require_envs
  local merge_request_iid="${1?}"
  local comment="${2?}"
  log "Comment on MR; merge_request_iid: $merge_request_iid, comment: $comment"
  curl -Sfs -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -d "body=$comment" \
    "$GITLAB_BASE_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests/${merge_request_iid}/notes"
}

# https://docs.gitlab.com/ee/api/commits.html#post-the-build-status-to-a-commit
post_build_status() {
  require_envs
  local sha="${1?}"
  local state="${2?}"
  local name="${3?}"
  local target_url="${4?}"

  if ! (echo "$state" | grep -qE '^(pending|running|success|failed|canceled)$'); then
    echo "error: Invalid state" >&2
    return 1
  fi

  log "Post build status; sha=$sha, state=$state, name=$name, target_url=$target_url"
  curl -Sfs -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_BASE_URL/api/v4/projects/$GITLAB_PROJECT_ID/statuses/${sha}" \
    -d "state=$state" \
    -d "name=$name" \
    -d "target_url=$target_url"
}

# Run command when merge request is updated.
hook_merge_requests() {
  local hooks_json_file="${1?}"

  local IFS=$'\n'
  local exit_status="0"
  for merge_request_json in $(cat - | jq -c '.[]'); do
    if echo "$merge_request_json" | hook_merge_request "$hooks_json_file"; then
      :
    else
      exit_status="$?"
    fi
  done
  return "$exit_status"
}

# Run command for merge request.
hook_merge_request() {
  : "${GITLAB_MR_HOOK_LOGDIR?}"
  local SHELL="${SHELL:-bash}"
  local merge_request_json
  merge_request_json="$(cat -)"
  local hooks_json_file="${1?}"

  mkdir -p "$GITLAB_MR_HOOK_LOGDIR"
  log "$(echo "$merge_request_json" | jq -r '"Checking MR \"\(.title)\" \(.labels) \(.source_branch) -> \(.target_branch) by \(.author.name) \(.web_url)"')"

  local exit_status="0"
  for hook_json in $(jq -c '.[]' < "$hooks_json_file"); do
    local hook_id
    hook_id="$(echo "$hook_json" | jq -r '.id')"
    local hook_filter
    hook_filter="$(echo "$hook_json" | jq -r '.filter')"
    local hook_cmd
    hook_cmd="$(echo "$hook_json" | jq -r '.cmd')"

    if test "$(echo "$merge_request_json" | jq "$hook_filter")" = 'true'; then
      log "$(echo "$hook_json" | jq -r '"Hook \"\(.id)\" is matched.  Run \"\(.cmd)\""')"

      local merge_request_iid
      merge_request_iid="$(echo "$merge_request_json" | jq -r '.iid')"
      local commit_sha
      commit_sha="$(echo "$merge_request_json" | jq -r '.sha')"
      local source_branch
      source_branch="$(echo "$merge_request_json" | jq -r '.source_branch')"
      local target_branch
      target_branch="$(echo "$merge_request_json" | jq -r '.target_branch')"
      local merge_request_url
      merge_request_url="$(echo "$merge_request_json" | jq -r '.web_url')"

      local commit_sha_short="${commit_sha:0:7}"
      local log_file="$GITLAB_MR_HOOK_LOGDIR/${hook_id}.${commit_sha_short}.log"

      if test -f "$log_file"; then
        log "=> SKIP.  Log file aleady exists.  See $log_file"
        continue
      fi

      if env MERGE_REQUEST_IID="$merge_request_iid" \
             SOURCE_BRANCH="$source_branch" \
             TARGET_BRANCH="$target_branch" \
             MERGE_REQUEST_URL="$merge_request_url" \
             "$SHELL" <(echo "$hook_cmd") &> "$log_file"; then
        log "=> SUCCESS.  See $log_file"
      else
        exit_status="$?"
        log "=> FAILED.  See $log_file"
      fi
    fi
  done

  return "$exit_status"
}

merge_request_json_for_jenkins() {
  : "${MERGE_REQUEST_IID?}"
  : "${SOURCE_BRANCH?}"
  : "${TARGET_BRANCH?}"
  : "${MERGE_REQUEST_URL?}"
  
  local template
  template=$(cat << 'EOS'
    {
      "parameter": [
        { "name": "MERGE_REQUEST_IID", "value": $merge_request_iid },
        { "name": "SOURCE_BRANCH",     "value": $source_branch },
        { "name": "TARGET_BRANCH",     "value": $target_branch },
        { "name": "MERGE_REQUEST_URL", "value": $merge_request_url }
      ]
    }
EOS
)
  
  jq -n -c \
    --arg merge_request_iid "$MERGE_REQUEST_IID" \
    --arg source_branch "$SOURCE_BRANCH" \
    --arg target_branch "$TARGET_BRANCH" \
    --arg merge_request_url "$MERGE_REQUEST_URL" \
    "$template"
}


if test "${BASH_SOURCE[0]}" = "$0"; then
  set -eu -o pipefail
  "$@"
fi
