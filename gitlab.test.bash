#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: list_merge_requests" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^GET /api/v4/projects/$GITLAB_PROJECT_ID/merge_requests\?state=opened&per_page=10000 HTTP/1.1"
  echo "$req" | grep -qE "^PRIVATE-TOKEN: ${GITLAB_PRIVATE_TOKEN}"
) &
request_validator_pid=$!
# when:
./gitlab.bash list_merge_requests
# then:
wait "$request_validator_pid"


echo "case: list_merge_requests fails when api returns 4xx" >&${stdout}
# given:
echo -e "HTTP/1.1 400 Bad Request\n\nBad Request" | busybox nc -l -p "$api_port" &
mock_server_pid=$!
# when:
./gitlab.bash list_merge_requests || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$mock_server_pid"


echo "case: comment_on_merge_request" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^POST /api/v4/projects/$GITLAB_PROJECT_ID/merge_requests/1/notes HTTP/1.1"
  echo "$req" | grep -qE "^body=Build started"
) &
request_validator_pid=$!
# when:
./gitlab.bash comment_on_merge_request --iid 1 --comment "Build started"
# then:
wait "$request_validator_pid"


echo "case: post_build_status" >&${stdout}
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req" | grep -qE "^POST /api/v4/projects/$GITLAB_PROJECT_ID/statuses/777 HTTP/1.1"
  echo "$req" | grep -qE "state=running&name=bash&target_url=http://localhost/target"
) &
request_validator_pid=$!
# when:
./gitlab.bash post_build_status --sha 777 --state running --name bash \
  --target-url http://localhost/target
# then:
wait "$request_validator_pid"


echo "case: post_build_status fails when invalid state is passed" >&${stdout}
# when:
./gitlab.bash post_build_status --sha 777 --state no-such-state --name bash \
  --target-url http://localhost/target || exit_status=$?
# then:
test "$exit_status" -ne 0


echo "case: hook_merge_requests_and_run_command" >&${stdout}
# given:
rm -rf ./tmp
# when:
# shellcheck disable=SC2016
./gitlab.bash hook_merge_requests_and_run_command --hook-id hook_merge_requests_test \
  --filter '.labels | map(. == "skip-ci") | any | not' --logdir ./tmp \
  --cmd 'echo "$MERGE_REQUEST_IID $SOURCE_BRANCH -> $TARGET_BRANCH ($MERGE_REQUEST_URL)"' \
  << MERGE_REQUESTS
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
# then:
test ! -f ./tmp/hook_merge_requests_test.001.log
test -f ./tmp/hook_merge_requests_test.002.log
test "$(cat ./tmp/hook_merge_requests_test.002.log)" = "2 source2 -> target2 (http://localhost/test2)"


echo "case: hook_merge_requests_and_run_command fail if cmd fail" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
merge_requests=$(cat << MERGE_REQUESTS
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
)
# when:
./gitlab.bash hook_merge_requests_and_run_command --hook-id hook_merge_requests_test \
  --filter 'true' --logdir ./tmp --cmd 'false' <<< "$merge_requests" || exit_status=$?
# then:
test "$exit_status" -ne 0


echo "case: hook_merge_requests_and_run_command skip execution if log exists" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
echo -n 'previous result' > ./tmp/hook_merge_requests_test.001.log
# when:
# shellcheck disable=SC2016
./gitlab.bash hook_merge_requests_and_run_command --hook-id hook_merge_requests_test \
  --filter 'true' --logdir ./tmp \
  --cmd 'echo "$MERGE_REQUEST_IID $SOURCE_BRANCH -> $TARGET_BRANCH ($MERGE_REQUEST_URL)"' \
  << MERGE_REQUESTS
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
# then:
test "$(cat ./tmp/hook_merge_requests_test.001.log)" = "previous result"


echo "case: merge_request_json_for_jenkins" >&${stdout}
# when:
json=$(env MERGE_REQUEST_IID=1 SOURCE_BRANCH=source TARGET_BRANCH=target MERGE_REQUEST_URL="http://localhost" ./gitlab.bash merge_request_json_for_jenkins)
# then:
test "$(echo "$json" | jq -r '.parameter[0].name')" = "MERGE_REQUEST_IID"
test "$(echo "$json" | jq -r '.parameter[0].value')" = "1"
test "$(echo "$json" | jq -r '.parameter[1].name')" = "SOURCE_BRANCH"
test "$(echo "$json" | jq -r '.parameter[1].value')" = "source"
test "$(echo "$json" | jq -r '.parameter[2].name')" = "TARGET_BRANCH"
test "$(echo "$json" | jq -r '.parameter[2].value')" = "target"
test "$(echo "$json" | jq -r '.parameter[3].name')" = "MERGE_REQUEST_URL"
test "$(echo "$json" | jq -r '.parameter[3].value')" = "http://localhost"


echo "case: hook_merge_requests success" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
merge_requests=$(cat << MR
[
  {
    "iid": "1",
    "title": "test mr 1",
    "sha": "001",
    "labels": [],
    "source_branch": "source1",
    "target_branch": "target1",
    "web_url": "http://localhost/test1"
  }
]
MR
)
cat > ./tmp/hooks.ltsv << HOOKS
hook_id:success	filter:.labels | map(. == "skip-ci") | any | not	cmd:echo "success"
HOOKS
# when:
echo "$merge_requests" \
  | ./gitlab.bash hook_merge_requests --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv
# then:
test "$(cat ./tmp/hook_log/success.001.log)" = "success"


echo "case: hook_merge_requests fail"
# given:
rm -rf ./tmp && mkdir ./tmp
merge_requests=$(cat << MR
[
  {
    "iid": "1",
    "title": "test mr 1",
    "sha": "001",
    "labels": [],
    "source_branch": "source1",
    "target_branch": "target1",
    "web_url": "http://localhost/test1"
  }
]
MR
)
cat > ./tmp/hooks.ltsv << HOOKS
hook_id:fail	filter:.labels | map(. == "skip-ci") | any | not	cmd:echo "fail"; false
hook_id:success	filter:.labels | map(. == "skip-ci") | any | not	cmd:echo "success"
HOOKS
# when:
echo "$merge_requests" \
  | ./gitlab.bash hook_merge_requests --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv || exit_status=$?

# then:
test "$exit_status" -ne 0
test "$(cat ./tmp/hook_log/fail.001.log)" = "fail"
test "$(cat ./tmp/hook_log/success.001.log)" = "success"


echo "case: hook_merge_requests trigger jenkins job"
# given:
rm -rf ./tmp && mkdir ./tmp
merge_requests=$(cat << MR
[
  {
    "iid": "1",
    "title": "test mr 1",
    "sha": "001",
    "labels": [],
    "source_branch": "source1",
    "target_branch": "target1",
    "web_url": "http://localhost/test1"
  }
]
MR
)
cat > ./tmp/hooks.ltsv << 'HOOKS'
hook_id:jenkins-example	filter:.labels | map(. == "skip-ci") | any | not	cmd:curl --verbose --silent --show-error --fail -X POST -u user:password "http://localhost:8080/job/test/build" -F json="$(./gitlab.bash merge_request_json_for_jenkins)"
HOOKS
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p 8080)
  # then:
  echo "$req" | grep -qE '^POST /job/test/build HTTP/1.1'
  echo "$req" | grep -q '^{"parameter":\[{"name":"MERGE_REQUEST_IID","value":"1"},{"name":"SOURCE_BRANCH","value":"source1"},{"name":"TARGET_BRANCH","value":"target1"},{"name":"MERGE_REQUEST_URL","value":"http://localhost/test1"}\]}'
) &
request_validator_pid=$!
# when:
echo "$merge_requests" \
  | ./gitlab.bash hook_merge_requests --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv
# then:
wait "$request_validator_pid"
