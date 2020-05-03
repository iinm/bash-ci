#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: show help message"
./hook_gitlab_merge_requests --help | grep -qE "^Usage"


echo "case: error on unknown option"
# when:
out=$(./hook_gitlab_merge_requests --no-such-option) || exit_status=$?
# then:
test "$exit_status" -ne 0
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: hook success"
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/mr.json << MR
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
cat > ./tmp/hooks.tsv << HOOKS
success	.labels | map(. == "skip-ci") | any | not	echo "success"
HOOKS
# when:
./hook_gitlab_merge_requests --logdir ./tmp/hook_log --merge-requests ./tmp/mr.json --hooks ./tmp/hooks.tsv
# then:
test "$(cat ./tmp/hook_log/success.001.log)" = "success"


echo "case: hook fail"
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/mr.json << MR
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
cat > ./tmp/hooks.tsv << HOOKS
fail	.labels | map(. == "skip-ci") | any | not	echo "fail"; false
success	.labels | map(. == "skip-ci") | any | not	echo "success"
HOOKS
# when:
./hook_gitlab_merge_requests --logdir ./tmp/hook_log --merge-requests ./tmp/mr.json --hooks ./tmp/hooks.tsv || exit_status=$?

# then:
test "$exit_status" -ne 0
test "$(cat ./tmp/hook_log/fail.001.log)" = "fail"
test "$(cat ./tmp/hook_log/success.001.log)" = "success"


echo "case: trigger jenkins job"
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/mr.json << MR
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
cat > ./tmp/hooks.tsv << 'HOOKS'
jenkins-example	.labels | map(. == "skip-ci") | any | not	curl --verbose --silent --show-error --fail -X POST -u user:password "http://localhost:8080/job/test/build" -F json="$(./gitlab.bash merge_request_json_for_jenkins)"
HOOKS
(
  # given:
  req=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p 8080)
  # then:
  echo "$req" | grep -qE '^POST /job/test/build HTTP/1.1'
  echo "$req" | grep -qE '^{"parameter":\[{"name":"MERGE_REQUEST_IID","value":"1"},{"name":"SOURCE_BRANCH","value":"source1"},{"name":"TARGET_BRANCH","value":"target1"},{"name":"MERGE_REQUEST_URL","value":"http://localhost/test1"}\]}'
) &
request_validator_pid=$!
# when:
./hook_gitlab_merge_requests --logdir ./tmp/hook_log --merge-requests ./tmp/mr.json --hooks ./tmp/hooks.tsv
# then:
wait "$request_validator_pid"
