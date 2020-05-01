#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

slack_api_port=8080
export SLACK_BASE_URL=http://localhost:$slack_api_port
export SLACK_API_TOKEN=test-token


echo "case: post_text_message show help message"
./slack.bash post_text_message --help | grep -qE '^Usage:'


echo "case: post_text_message"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  echo "$req" | grep -qE "^POST /api/chat.postMessage HTTP/1.1"
  echo "$req" | grep -qE "^Authorization: Bearer ${SLACK_API_TOKEN}"
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .channel)" = "random"
  test "$(echo "$body" | jq -r .text)" = "Hello World!"
) &
./slack.bash post_text_message --channel "random" --text "Hello World!" > /dev/null
wait "$(jobs -p)"


echo "case: post_text_message with custom user name and user icon"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .username)" = "Bash"
  test "$(echo "$body" | jq -r .icon_url)" = "http://localhost/icon.png"
) &
./slack.bash post_text_message --channel "random" --text "Hello World!" \
  --user-name "Bash" --user-icon "http://localhost/icon.png" > /dev/null
wait "$(jobs -p)"


echo "case: post_text_message fails when API returns 4xx"
(
  echo -e "HTTP/1.1 400 Bad Request\n\nBad Request" | busybox nc -l -p "$slack_api_port" > /dev/null
) &
if ./slack.bash post_text_message --channel "random" --text "Hello World!" > /dev/null; then
  echo "error: command should fail" >&2
fi
wait "$(jobs -p)"


echo "case: post_message"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  echo "$req" | grep -qE "^POST /api/chat.postMessage HTTP/1.1"
  echo "$req" | grep -qE "^Authorization: Bearer ${SLACK_API_TOKEN}"
  echo "$req" | grep -qE '"text": "Hello World!"'
) &
./slack.bash post_message > /dev/null << 'MESSAGE'
{
  "as_user": false,
  "username": "Bash",
  "icon_url": "http://localhost/icon.png",
  "channel": "random",
  "text": "Hello World!"
}
MESSAGE
wait "$(jobs -p)"
