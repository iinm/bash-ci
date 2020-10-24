#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

echo "case: show help message"
# when:
./git.bash has_remote_update --help | grep -qE '^Usage:'


echo "case: hook_push success"
# given:
rm -rf ./tmp && mkdir ./tmp
git_ls_remote_output=$(cat << OUTPUT
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	HEAD
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	refs/heads/master
OUTPUT
)
cat > ./tmp/hooks.ltsv << HOOKS
hook_id:success	refs_pattern:/(master|tags/.+)$	cmd:echo "success"
HOOKS
# when:
echo "$git_ls_remote_output" \
  | ./git.bash hook_push --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv

# then:
test "$(cat ./tmp/hook_log/success.65ba1d7.log)" = "success"


echo "case: hook_push runs all hooks but fails if any hook fails"
# given:
rm -rf ./tmp && mkdir ./tmp
git_ls_remote_output=$(cat << OUTPUT
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	HEAD
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	refs/heads/master
OUTPUT
)
cat > ./tmp/hooks.ltsv << HOOKS
hook_id:fail	refs_pattern:/(master|tags/.+)$	cmd:echo "fail"; false
hook_id:success	refs_pattern:/(master|tags/.+)$	cmd:echo "success"
HOOKS
# when:
exit_status=0
echo "$git_ls_remote_output" \
  | ./git.bash hook_push --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv || exit_status=$?

# then:
test "$exit_status" -ne 0
test "$(cat ./tmp/hook_log/fail.65ba1d7.log)" = "fail"
test "$(cat ./tmp/hook_log/success.65ba1d7.log)" = "success"


echo "case: hook_push doesn't run executed hooks"
# given:
rm -rf ./tmp && mkdir ./tmp
git_ls_remote_output=$(cat << OUTPUT
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	HEAD
65ba1d742beecdbbed3a7dc89d9b5b5ed5dd6c2b	refs/heads/master
OUTPUT
)
cat > ./tmp/hooks.ltsv << HOOKS
hook_id:already_run	refs_pattern:/(master|tags/.+)$	cmd:echo "executed twice!"
HOOKS
mkdir -p ./tmp/hook_log
echo "executed once." > ./tmp/hook_log/already_run.65ba1d7.log
# when:
echo "$git_ls_remote_output" \
  | ./git.bash hook_push --logdir ./tmp/hook_log --hooks ./tmp/hooks.ltsv

# then:
test "$(cat ./tmp/hook_log/already_run.65ba1d7.log)" = "executed once."
