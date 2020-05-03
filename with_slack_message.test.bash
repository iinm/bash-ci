#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

slack_api_port=8080
export SLACK_BASE_URL=http://localhost:$slack_api_port
export SLACK_API_TOKEN=test-token


echo "case: show help message" >&${stdout}
./with_slack_message --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_slack_message --no-such-option) || exit_status=$?
# then:
test "$exit_status" -ne 0
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: post start message on start and success message on success" >&${stdout}
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
  true
# then:
wait "$request_validator_pid"


echo "case: post fail message on fail" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  # then:
  body=$(echo "$req" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "fail"
) &
request_validator_pid=$!
# when:
./with_slack_message --channel "random" --message-on-success "success" --message-on-fail "fail" \
  false || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"


echo "case: post cancel message on cancel" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$slack_api_port")
  # then:
  body=$(echo "$req" | grep -A 100 -E '^\s+$')
  test "$(echo "$body" | jq -r .text)" = "cancel"
) &
request_validator_pid=$!
# when:
./with_slack_message --channel "random" --message-on-cancel "cancel" sleep 5 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
