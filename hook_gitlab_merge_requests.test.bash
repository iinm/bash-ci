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
