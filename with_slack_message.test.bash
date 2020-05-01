#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

slack_api_port=8080
export SLACK_BASE_URL=http://localhost:$slack_api_port
export SLACK_API_TOKEN=test-token


echo "case: show help message"
./with_slack_message --help | grep -qE "^Usage"


echo "case: post start on start and success message on success"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .text)" = "start"

  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .text)" = "success"
) &
./with_slack_message --channel "random" \
  --message-on-start "start" --message-on-success "success" \
  true > /dev/null
wait "$(jobs -p)"


echo "case: post fail message on fail"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .text)" = "fail"
) &
if ./with_slack_message --channel "random" --message-on-success "success" --message-on-fail "fail" \
  false > /dev/null; then
  echo "error: command should fail" >&2
  exit 1
fi
wait "$(jobs -p)"


echo "case: post cancel message on cancel"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$slack_api_port")
  body=$(echo "$req" | gawk '/^{/,/^}/')
  test "$(echo "$body" | jq -r .text)" = "cancel"
) &
./with_slack_message --channel "random" --message-on-cancel "cancel" sleep 5 > /dev/null &
pid=$!
sleep 1
kill -s HUP "$pid"
if wait "$pid"; then
  echo "error: command should fail" >&2
  exit 1
fi
wait "$(jobs -p)"
