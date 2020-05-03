#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

slack_api_port=8080
export SLACK_BASE_URL=http://localhost:$slack_api_port
export SLACK_API_TOKEN=test-token


echo "case: show help message"
./with_slack_message --help | grep -qE "^Usage"


echo "case: error on unknown option"
# when:
if out=$(./with_slack_message --no-such-option); then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: post start message on start and success message on success"
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  # then:
  body=$(echo "$req1" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "start"
  body=$(echo "$req2" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "success"
) &
request_validator_pid=$!
# when:
./with_slack_message --channel "random" \
  --message-on-start "start" --message-on-success "success" \
  true >&2
# then:
wait "$request_validator_pid"


echo "case: post fail message on fail"
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  # then:
  body=$(echo "$req" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "fail"
) &
request_validator_pid=$!
# when:
if ./with_slack_message --channel "random" --message-on-success "success" --message-on-fail "fail" \
  false >&2; then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
wait "$request_validator_pid"


echo "case: post cancel message on cancel"
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  # then:
  body=$(echo "$req" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "cancel"
) &
request_validator_pid=$!
# when:
./with_slack_message --channel "random" --message-on-cancel "cancel" sleep 5 >&2 &
pid=$!
sleep 1
kill -s HUP "$pid"
if wait "$pid"; then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
wait "$request_validator_pid"
