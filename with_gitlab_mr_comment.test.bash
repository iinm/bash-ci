#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: show help message" >&${stdout}
# when:
./with_gitlab_mr_comment --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_gitlab_mr_comment --no-such-option) || exit_status=$?
# then:
test "$exit_status" -ne 0
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: post start comment on start and success comment on success" >&${stdout}
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^body=start"
  echo "$req2" | grep -qE "^body=success"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid 1 \
  --comment-on-start "start" --comment-on-success "success" \
  echo "Hello"
# then:
wait "$request_validator_pid"


echo "case: post fail comment on fail" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^body=fail"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid 1 --comment-on-fail "fail" false || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"


echo "case: post cancel comment on cancel" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^body=cancel"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid 1 --comment-on-cancel "cancel" sleep 5 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
