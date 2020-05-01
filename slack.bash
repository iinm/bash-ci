#!/usr/bin/env bash

: "${SLACK_BASE_URL:="https://slack.com"}"

post_text_message() {
  : "${SLACK_API_TOKEN:?}"
  local channel text user_name user_icon
  while true; do
    if test "$#" -eq 0; then
      break
    fi
    case "$1" in
      --help ) 
        echo "Usage: ${FUNCNAME[0]} --channel CHANNEL --text TEXT [--user-name NAME] [--user-icon URL]"
        return 0
        ;;
      --channel ) channel=$2; shift 2 ;;
      --text ) text=$2; shift 2 ;;
      --user-name ) user_name=$2; shift 2 ;;
      --user-icon ) user_icon=$2; shift 2 ;;
      * ) break ;;
  esac
  done
  : "${channel?}"
  : "${text?}"
  : "${user_name:="Bot"}"
  : "${user_icon:="https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/GNOME_Builder_Icon_%28hicolor%29.svg/240px-GNOME_Builder_Icon_%28hicolor%29.svg.png"}"

  local body_template body
  body_template=$(cat << 'EOS'
    {
      "as_user": false,
      "username": $username,
      "icon_url": $icon_url,
      "channel": $channel,
      "text": $text
    }
EOS
)
  body=$(
    jq -n \
      --arg username "$user_name" \
      --arg icon_url "$user_icon" \
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
