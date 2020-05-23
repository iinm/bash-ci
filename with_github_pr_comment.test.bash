#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITHUB_BASE_URL=http://localhost:$api_port
export GITHUB_TOKEN=test-token
export GITHUB_REPO=iinm/bash-ci


echo "case: show help message" >&${stdout}
# when:
./with_github_pr_comment --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_github_pr_comment --no-such-option) || exit_status=$?
# then:
test "$exit_status" -ne 0
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: post start comment on start and success comment on success" >&${stdout}
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -q 'start'
  echo "$req2" | grep -q 'success'
) &
request_validator_pid=$!
# when:
./with_github_pr_comment --id 1 \
  --comment-on-start "start" --comment-on-success "success" \
  echo "Hello"
# then:
wait "$request_validator_pid"


echo "case: post fail comment on fail" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -q "fail"
) &
request_validator_pid=$!
# when:
./with_github_pr_comment --id 1 --comment-on-fail "fail" false || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"


echo "case: post cancel comment on cancel" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -q "cancel"
) &
request_validator_pid=$!
# when:
./with_github_pr_comment --id 1 --comment-on-cancel "cancel" sleep 5 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
