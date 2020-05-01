#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: show help message"
./with_gitlab_mr_comment --help | grep -qE "^Usage"


echo "case: post start comment on start and success comment on success"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^body=start"
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^body=success"
) &
./with_gitlab_mr_comment --iid 1 \
  --comment-on-start "start" --comment-on-success "success" \
  echo "Hello" >&2
wait "$(jobs -p)"


echo "case: post fail comment on fail"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^body=fail"
) &
if ./with_gitlab_mr_comment --iid 1 --comment-on-fail "fail" false >&2; then
  echo "error: command should fail" >&2
  exit 1
fi
wait "$(jobs -p)"


echo "case: post cancel comment on cancel"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^body=cancel"
) &
./with_gitlab_mr_comment --iid 1 --comment-on-cancel "cancel" sleep 5 >&2 &
pid=$!
sleep 1
kill -s HUP "$pid"
if wait "$pid"; then
  echo "error: command should fail" >&2
  exit 1
fi
wait "$(jobs -p)"
