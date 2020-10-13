#!/usr/bin/env bash

log() {
  echo "$(date "+%Y-%m-%d %H:%M:%S")" "$@" >&2
}

require_envs() {
  : "${GITHUB_BASE_URL:?}"
  : "${GITHUB_REPO:?}"
  : "${GITHUB_TOKEN:?}"
}

list_pull_requests() {
  require_envs
  local params=${1:-"state=open"}
  curl --silent --show-error --fail -X GET \
    "$GITHUB_BASE_URL/api/v3/repos/$GITHUB_REPO/pulls?$params" \
    -H "Authorization: token $GITHUB_TOKEN"
}

comment_on_pull_request() {
  local pull_request_id comment
  while test "$#" -gt 0; do
    case "$1" in
      --help ) 
        echo "Usage: ${FUNCNAME[0]} --id PULL_REQUEST_ID --comment COMMENT"
        return 0
        ;;
      --id      ) pull_request_id=$2; shift 2 ;;
      --comment ) comment=$2; shift 2 ;;
      --*       ) echo "error: unknown option $1"; return 1 ;;
      *         ) break ;;
    esac
  done
  require_envs
  : "${pull_request_id?}"
  : "${comment?}"

  log "Comment on PR; pull_request_id: $pull_request_id, comment: $comment"
  curl --silent --show-error --fail -X POST \
    "$GITHUB_BASE_URL/api/v3/repos/$GITHUB_REPO/issues/$pull_request_id/comments" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -d "$(jq -n -c --arg body "$comment" '{ "body": $body }')"
}

# https://developer.github.com/v3/repos/statuses/
post_build_status() {
  local sha state description context target_url
  while test "$#" -gt 0; do
    case "$1" in
      --help ) 
        echo "Usage: ${FUNCNAME[0]} --sha COMMIT_SHA --context BUILD_SYSTEM --state STATE --description DESCRIPTION --target-url BUILD_SYSTEM_URL"
        return 0
        ;;
      --sha         ) sha=$2; shift 2 ;;
      --context     ) context=$2; shift 2 ;;
      --state       ) state=$2; shift 2 ;;
      --description ) description=$2; shift 2 ;;
      --target-url  ) target_url=$2; shift 2 ;;
      --*           ) echo "error: unknown option $1"; return 1 ;;
      *             ) break ;;
    esac
  done

  require_envs
  : "${sha?}"
  : "${context:=""}"
  : "${state?}"
  : "${description:=""}"
  : "${target_url:=""}"

  if ! (echo "$state" | grep -qE '^(error|failure|pending|success)$'); then
    echo "error: Invalid state" >&2
    return 1
  fi

  log "Post build status; sha=$sha, context=$context, state=$state, description=$description, target_url=$target_url"
  local body
  body=$(
    jq -n -c \
      --arg state "$state" \
      --arg description "$description" \
      --arg context "$context" \
      --arg target_url "$target_url" \
      '{ "state": $state, "target_url", $target_url, "description": $description, "context": $context }'
  )
  curl --silent --show-error --fail -X POST \
    "$GITHUB_BASE_URL/api/v3/repos/$GITHUB_REPO/statuses/$sha" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -d "$body"
}

hook_pull_requests() {
  while test "$#" -gt 0; do
    case "$1" in
      --help )
        echo "Usage: ${FUNCNAME[0]} --logdir DIR --hooks TSV_FILE < PULL_REQUESTS_JSON_FILE"
        return 0
        ;;
      --logdir ) logdir=$2; shift 2 ;;
      --hooks  ) hooks=$2; shift 2 ;;
      --*      ) echo "error: unknown option $1"; return 1 ;;
      *        ) break ;;
    esac
  done

  : "${logdir?}"
  : "${hooks?}"
  pull_requests=$(cat -)

  exit_status=0
  while read -r line; do
    hook_id=$(echo "$line" | value_from_ltsv "hook_id")
    filter=$(echo "$line" | value_from_ltsv "filter")
    cmd=$(echo "$line" | value_from_ltsv "cmd")
    echo "$pull_requests" \
      | hook_pull_requests_and_run_command --logdir "$logdir" --hook-id "$hook_id" --filter "$filter" --cmd "$cmd" || exit_status=$?
  done < "$hooks"

  return "$exit_status"
}

value_from_ltsv() {
  key="${1?}"
  sed -E "s/(^|.+	)${key}:([^	]*).*/\2/"
}

hook_pull_requests_and_run_command() {
  local hook_id filter logdir cmd
  while test "$#" -gt 0; do
    case "$1" in
      --help ) 
        echo "Usage: ${FUNCNAME[0]} --logdir DIR --hook-id ID --filter FILTER --cmd CMD < PULL_REQUESTS_JSON_FILE"
        return 0
        ;;
      --logdir  ) logdir=$2; shift 2 ;;
      --hook-id ) hook_id=$2; shift 2 ;;
      --filter  ) filter=$2; shift 2 ;;
      --cmd     ) cmd=$2; shift 2 ;;
      --*       ) echo "error: unknown option $1"; return 1 ;;
      *         ) break ;;
    esac
  done

  : "${hook_id?}"
  : "${filter?}"
  : "${cmd?}"
  : "${logdir?}"

  local full_filter
  full_filter=$(cat << FILTER
    map(select($filter))
      | map("\(.id)\t\(.title)\t\(.labels | map(.name))\t\(.head.ref)\t\(.base.ref)\t\(.head.sha)\t\(.url)")
      | .[]
FILTER
)

  local exit_status=0
  while IFS=$'\t' read -r id title labels head_ref base_ref sha url; do
    log "($hook_id) hooked \"$title\" $head_ref -> $base_ref $labels"

    local commit_sha_short="${sha:0:7}"
    local log_file="$logdir/${hook_id}.${commit_sha_short}.log"

    if test -f "$log_file"; then
      log "=> skip; log exists $log_file"
      continue
    fi

    mkdir -p "$(dirname "$log_file")"
    if env PULL_REQUEST_ID="$id" \
      HEAD_REF="$head_ref" BASE_REF="$base_ref" \
      PULL_REQUEST_URL="$url" \
      bash -ue -o pipefail -c "$cmd" &> "$log_file"; then
      log "=> success; $log_file"
    else
      exit_status=$?
      log "=> failed; $log_file"
    fi
  done < <(jq -r -c "$full_filter")
  return "$exit_status"
}

pull_request_json_for_jenkins() {
  : "${PULL_REQUEST_ID?}"
  : "${HEAD_REF?}"
  : "${BASE_REF?}"
  : "${PULL_REQUEST_URL?}"
  
  local template
  template=$(cat << 'EOS'
    {
      "parameter": [
        { "name": "PULL_REQUEST_ID",  "value": $pull_request_id },
        { "name": "HEAD_REF",         "value": $head_ref },
        { "name": "BASE_REF",         "value": $base_ref },
        { "name": "PULL_REQUEST_URL", "value": $pull_request_url }
      ]
    }
EOS
)
  
  jq -n -c \
    --arg pull_request_id "$PULL_REQUEST_ID" \
    --arg head_ref "$HEAD_REF" \
    --arg base_ref "$BASE_REF" \
    --arg pull_request_url "$PULL_REQUEST_URL" \
    "$template"
}


if test "${BASH_SOURCE[0]}" = "$0"; then
  set -eu -o pipefail
  "$@"
fi
