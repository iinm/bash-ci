#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export SLACK_BASE_URL=http://localhost:$api_port
export SLACK_API_TOKEN=test-token


echo "case: post_text_message show help message" >&${stdout}
# when:
./slack.bash post_text_message --help | grep -qE '^Usage:'


echo "case: post_text_message" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^POST /api/chat.postMessage HTTP/1.1"
  echo "$req" | grep -qE "^Authorization: Bearer ${SLACK_API_TOKEN}"
  body=$(echo "$req" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .channel)" = "random"
  test "$(echo "$body" | jq -r .text)" = "Hello World!"
) &
request_validator_pid=$!
# when:
./slack.bash post_text_message --channel "random" --text "Hello World!"
# then:
wait "$request_validator_pid"


echo "case: post_text_message fails when API returns 4xx" >&${stdout}
# given:
echo -e "HTTP/1.1 400 Bad Request\n\nBad Request" | busybox nc -l -p "$api_port" &
mock_server_pid=$!
# when:
./slack.bash post_text_message --channel "random" --text "Hello World!" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$mock_server_pid"


echo "case: post_message" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^POST /api/chat.postMessage HTTP/1.1"
  echo "$req" | grep -qE "^Authorization: Bearer ${SLACK_API_TOKEN}"
  echo "$req" | grep -qE '"text": "Hello World!"'
) &
request_validator_pid=$!
# when:
./slack.bash post_message << 'MESSAGE'
{
  "channel": "random",
  "text": "Hello World!"
}
MESSAGE
# then:
wait "$request_validator_pid"
