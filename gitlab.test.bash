#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: list_merge_requests"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^GET /api/v4/projects/$GITLAB_PROJECT_ID/merge_requests\?state=opened&per_page=10000 HTTP/1.1"
  echo "$req" | grep -qE "^PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}"
) &
./gitlab.bash list_merge_requests > /dev/null
wait "$(jobs -p)"


echo "case: list_merge_requests fails when api returns 4xx"
(
  req=$(echo -e "HTTP/1.1 400 Bad Request\n\nBad Request" | busybox nc -l -p "$api_port")
) &
if ./gitlab.bash list_merge_requests > /dev/null; then
  echo "error: command should fail" >&2
  exit 1
fi
wait "$(jobs -p)"


echo "case: comment_on_merge_request"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^POST /api/v4/projects/$GITLAB_PROJECT_ID/merge_requests/1/notes HTTP/1.1"
  echo "$req" | grep -qE "^body=Build started"
) &
./gitlab.bash comment_on_merge_request --iid 1 --comment "Build started" > /dev/null
wait "$(jobs -p)"


echo "case: post_build_status"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^POST /api/v4/projects/$GITLAB_PROJECT_ID/statuses/777 HTTP/1.1"
  echo "$req" | grep -qE "state=running&name=bash&target_url=http://localhost/target"
) &
./gitlab.bash post_build_status --sha 777 --state running --name bash \
  --target-url http://localhost/target > /dev/null
wait "$(jobs -p)"


echo "case: post_build_status fails when invalid state is passed"
if ./gitlab.bash post_build_status --sha 777 --state no-such-state --name bash \
  --target-url http://localhost/target > /dev/null; then
  echo "error: command should fail" >&2
  exit 1
fi
