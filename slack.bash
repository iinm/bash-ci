#!/usr/bin/env bash

post_text_message() {
  : "${SLACK_API_TOKEN:?}"
  : "${SLACK_USER_NAME:="Bot"}"
  : "${SLACK_USER_ICON:="https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/GNOME_Builder_Icon_%28hicolor%29.svg/240px-GNOME_Builder_Icon_%28hicolor%29.svg.png"}"
  channel=${1:?}
  text=${2:?}

  body_template=$(cat << 'EOS'
    {
      "as_user": false,
      "username": $username,
      "icon_url": $icon,
      "channel": $channel,
      "text": $text
    }
EOS
)
  body=$(
    jq -n \
      --arg username "$SLACK_USER_NAME" \
      --arg icon "$SLACK_USER_ICON" \
      --arg channel "$channel" \
      --arg text "$text" \
      "$body_template"
  )
  curl -Sfs -X POST 'https://slack.com/api/chat.postMessage' \
    -H "Authorization: Bearer $SLACK_API_TOKEN" \
    -H "Content-type: application/json; charset=utf-8" \
    -d "$body"
}

post_message() {
  : "${SLACK_API_TOKEN:?}"
  curl -Sfs -X POST 'https://slack.com/api/chat.postMessage' \
    -H "Authorization: Bearer $SLACK_API_TOKEN" \
    -H "Content-type: application/json; charset=utf-8" \
    -d @-
}

email2userid() {
  : "${SLACK_API_TOKEN:?}"
  email="${1?}"
  curl -Sfs -X GET \
    'https://slack.com/api/users.list' \
    -H "Authorization: Bearer $SLACK_API_TOKEN" \
    | jq -r ".members | map(select(.profile.email == \"$email\")) | .[0].id"
}
