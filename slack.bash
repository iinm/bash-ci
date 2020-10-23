#!/usr/bin/env bash

: "${SLACK_BASE_URL:="https://slack.com"}"

post_text_message() {
  local channel text
  while test "$#" -gt 0; do
    case "$1" in
      --help ) 
        echo "Usage: ${FUNCNAME[0]} --channel CHANNEL --text TEXT"
        return 0
        ;;
      --channel   ) channel=$2; shift 2 ;;
      --text      ) text=$2; shift 2 ;;
      *           ) break ;;
  esac
  done
  : "${SLACK_API_TOKEN:?}"
  : "${channel?}"
  : "${text?}"

  local body_template body
  body_template=$(cat << 'EOS'
    {
      "channel": $channel,
      "text": $text
    }
EOS
)
  body=$(
    jq -n \
      --arg channel "$channel" \
      --arg text "$text" \
      "$body_template"
  )
  curl --silent --show-error --fail -X POST "${SLACK_BASE_URL}/api/chat.postMessage" \
    -H "Authorization: Bearer ${SLACK_API_TOKEN?}" \
    -H "Content-type: application/json; charset=utf-8" \
    -d "$body"
}

post_message() {
  : "${SLACK_API_TOKEN:?}"
  curl --silent --show-error --fail -X POST "${SLACK_BASE_URL}/api/chat.postMessage" \
    -H "Authorization: Bearer $SLACK_API_TOKEN" \
    -H "Content-type: application/json; charset=utf-8" \
    -d @-
}

email2userid() {
  : "${SLACK_API_TOKEN:?}"
  local email="${1?}"
  curl --silent --show-error --fail -X GET \
    "$SLACK_BASE_URL/users.list" \
    -H "Authorization: Bearer $SLACK_API_TOKEN" \
    | jq -r ".members | map(select(.profile.email == \"$email\")) | .[0].id"
}


if test "${BASH_SOURCE[0]}" = "$0"; then
  set -eu -o pipefail
  "$@"
fi
