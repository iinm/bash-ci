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
./gitlab.bash list_merge_requests >&2
wait "$(jobs -p)"


echo "case: list_merge_requests fails when api returns 4xx"
(
  req=$(echo -e "HTTP/1.1 400 Bad Request\n\nBad Request" | busybox nc -l -p "$api_port")
) &
if ./gitlab.bash list_merge_requests >&2; then
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
./gitlab.bash comment_on_merge_request --iid 1 --comment "Build started" >&2
wait "$(jobs -p)"


echo "case: post_build_status"
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^POST /api/v4/projects/$GITLAB_PROJECT_ID/statuses/777 HTTP/1.1"
  echo "$req" | grep -qE "state=running&name=bash&target_url=http://localhost/target"
) &
./gitlab.bash post_build_status --sha 777 --state running --name bash \
  --target-url http://localhost/target >&2
wait "$(jobs -p)"


echo "case: post_build_status fails when invalid state is passed"
if ./gitlab.bash post_build_status --sha 777 --state no-such-state --name bash \
  --target-url http://localhost/target >&2; then
  echo "error: command should fail" >&2
  exit 1
fi


echo "case: hook_merge_requests"
rm -rf ./tmp
# shellcheck disable=SC2016
./gitlab.bash hook_merge_requests --verbose --task-id hook_merge_requests_test \
  --filter '.labels | map(. == "skip-ci") | any | not' --logdir ./tmp \
  --cmd 'echo "$MERGE_REQUEST_IID $SOURCE_BRANCH -> $TARGET_BRANCH ($MERGE_REQUEST_URL)"' \
  << 'MERGE_REQUESTS'
[
  {
    "iid": "1",
    "title": "test mr 1",
    "sha": "001",
    "labels": ["skip-ci"],
    "source_branch": "source1",
    "target_branch": "target1",
    "web_url": "http://localhost/test1"
  },
  {
    "iid": "2",
    "title": "test mr 2",
    "sha": "002",
    "labels": [],
    "source_branch": "source2",
    "target_branch": "target2",
    "web_url": "http://localhost/test2"
  }
]
MERGE_REQUESTS
test ! -f ./tmp/hook_merge_requests_test.001.log
test -f ./tmp/hook_merge_requests_test.002.log
test "$(cat ./tmp/hook_merge_requests_test.002.log)" = "2 source2 -> target2 (http://localhost/test2)"


echo "case: hook_merge_requests skip execution if log exists"
rm -rf ./tmp
mkdir ./tmp
echo -n 'previous result' > ./tmp/hook_merge_requests_test.001.log
# shellcheck disable=SC2016
./gitlab.bash hook_merge_requests --verbose --task-id hook_merge_requests_test \
  --filter 'true' --logdir ./tmp \
  --cmd 'echo "$MERGE_REQUEST_IID $SOURCE_BRANCH -> $TARGET_BRANCH ($MERGE_REQUEST_URL)"' \
  << 'MERGE_REQUESTS'
[
  {
    "iid": "1",
    "title": "test mr 1",
    "sha": "001",
    "labels": ["skip-ci"],
    "source_branch": "source1",
    "target_branch": "target1",
    "web_url": "http://localhost/test1"
  }
]
MERGE_REQUESTS
test "$(cat ./tmp/hook_merge_requests_test.001.log)" = "previous result"


echo "case: merge_request_json_for_jenkins"
json=$(env MERGE_REQUEST_IID=1 SOURCE_BRANCH=source TARGET_BRANCH=target MERGE_REQUEST_URL="http://localhost" ./gitlab.bash merge_request_json_for_jenkins)
test "$(echo "$json" | jq -r '.parameter[0].name')" = "MERGE_REQUEST_IID"
test "$(echo "$json" | jq -r '.parameter[0].value')" = "1"
test "$(echo "$json" | jq -r '.parameter[1].name')" = "SOURCE_BRANCH"
test "$(echo "$json" | jq -r '.parameter[1].value')" = "source"
test "$(echo "$json" | jq -r '.parameter[2].name')" = "TARGET_BRANCH"
test "$(echo "$json" | jq -r '.parameter[2].value')" = "target"
test "$(echo "$json" | jq -r '.parameter[3].name')" = "MERGE_REQUEST_URL"
test "$(echo "$json" | jq -r '.parameter[3].value')" = "http://localhost"
