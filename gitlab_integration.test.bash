#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: combine mr comment and pipeline; success"
(
  # given:
  # comment start
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline running
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline success
  req3=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # comment success
  req4=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^body=start"
  echo "$req2" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req3" | grep -qE "^state=success&name=Bash&target_url=http://localhost"
  echo "$req4" | grep -qE "^body=success"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid "3" \
  --comment-on-start "start" \
  --comment-on-cancel "cancel" \
  --comment-on-success "success" \
  --comment-on-fail "fail" \
  ./with_gitlab_pipeline --commit-sha "777" \
    --build-system-name "Bash" --build-url "http://localhost" \
  echo "Hello" >&2
# then:
wait "$request_validator_pid"


echo "case: combine mr comment and pipeline; fail"
(
  # given:
  # comment start
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline running
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline failed
  req3=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # comment fail
  req4=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^body=start"
  echo "$req2" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req3" | grep -qE "^state=failed&name=Bash&target_url=http://localhost"
  echo "$req4" | grep -qE "^body=fail"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid "3" \
  --comment-on-start "start" \
  --comment-on-cancel "cancel" \
  --comment-on-success "success" \
  --comment-on-fail "fail" \
  ./with_gitlab_pipeline --commit-sha "777" \
    --build-system-name "Bash" --build-url "http://localhost" \
    false >&2 || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"


echo "case: combine mr comment and pipeline; cancel"
(
  # given:
  # comment start
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline running
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # pipeline canceled
  req3=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # comment cancel
  req4=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^body=start"
  echo "$req2" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req3" | grep -qE "^state=canceled&name=Bash&target_url=http://localhost"
  echo "$req4" | grep -qE "^body=cancel"
) &
request_validator_pid=$!
# when:
./with_gitlab_mr_comment --iid "3" \
  --comment-on-start "start" \
  --comment-on-cancel "cancel" \
  --comment-on-success "success" \
  --comment-on-fail "fail" \
  ./with_gitlab_pipeline --commit-sha "777" \
    --build-system-name "Bash" --build-url "http://localhost" \
  sleep 5 >&2 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
