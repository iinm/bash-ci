#!/usr/bin/env bash

set -eu

merge_requests() {
  : "${GITLAB_BASE_URL:?}"
  : "${GITLAB_PROJECT_ID:?}"
  : "${GITLAB_PRIVATE_TOKEN:?}"
  params=${1:-"state=opened&per_page=10000"}
  curl --silent -X GET "$GITLAB_BASE_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests?$params" -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN"
}

hook() {
  script_dir="${1?}"
  history_dir="${2?}"

  local IFS=$'\n'
  for req in $(cat - | jq -c '.[]'); do
    for script_file in $(find "$script_dir" -type f); do
      if should_hook "$script_file" "$req"; then
        run "$script_file" "$req" "$history_dir"
      fi
    done
  done
}

should_hook() {
  script_file="${1?}"
  request_json="${2?}"

  filter=$(grep -E '# filter:' "$script_file" | sed -E 's,# filter: (.+),\1,')
  test "$(echo "$request_json" | jq "$filter")" = "true"
}

run() {
  script_file="${1?}"
  request="${2?}"
  history_dir="${3?}"

  request_id="$(echo "$request" | jq -r '.id')"
  request_iid="$(echo "$request" | jq -r '.iid')"
  commit_sha="$(echo "$request" | jq -r '.sha')"
  source_branch="$(echo "$request" | jq -r '.source_branch')"
  target_branch="$(echo "$request" | jq -r '.target_branch')"

  history_file="${history_dir}/$(basename "$script_file")--${request_iid}--${commit_sha}"

  if test -f "$history_file"; then
    return 0
  fi

  echo -e "\nRUN $script_file"
  env request_id="$request_id" \
      request_iid="$request_iid" \
      source_branch="$source_branch" \
      target_branch="$target_branch" \
      bash -c "$(cat "$script_file")" || true
  touch "$history_file"
}


: "${GITLAB_BASE_URL:?}"
: "${GITLAB_PROJECT_ID:?}"
: "${GITLAB_PRIVATE_TOKEN:?}"

script_dir="${1?}"
history_dir="${2?}"

merge_requests "state=opened&per_page=10000" | hook "$script_dir" "$history_dir"
