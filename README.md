# GitLab API Client for Bash

## Usage

Set environment variables.
```sh
export GITLAB_BASE_URL="https://gitlab.com"
export GITLAB_PRIVATE_TOKEN="your token"   # https://gitlab.com/profile/personal_access_tokens
export GITLAB_PROJECT_ID="your project id"
```

Run command when merge request is created / updated.
```sh
hooks=$(cat << 'EOF'
[
  {
    "id": "test",
    "filter": ".labels[] | contains(\"test\")",
    "cmd": "echo \"id: $MERGE_REQUEST_IID source: $SOURCE_BRANCH -> target: $TARGET_BRANCH\""
  },
  {
    "id": "test-jenkins",
    "filter": ".labels[] | contains(\"jenkins-test\")",
    "cmd": "curl -X POST -u $JENKINS_AUTH \"http://localhost/jenkins/job/test/buildWithParameters?SOURCE_BRANCH=$SOURCE_BRANCH&TARGET_BRANCH=$TARGET_BRANCH&MERGE_REQUEST_IID=$MERGE_REQUEST_IID\""
  }
]
EOF
)
export GITLAB_MR_HOOK_LOGDIR=hook_log  # Save log to avoid double execution.
./gitlab list_merge_requests | ./gitlab hook_merge_requests <(echo "$hooks")
```

- `filter` : [jq](https://stedolan.github.io/jq/manual/) filter to select merge request to hook.
- `cmd` : Command you want to execute when merge request is created / updated.
  - `$MERGE_REQUEST_IID`, `$SOURCE_BRANCH`, `$TARGET_BRANCH` are automatically set.


Run command as Pipeline job.
```sh
export GITLAB_COMMIT_SHA="43127becfba9ffdc52715c006c1d36eeef8fb8ef"
export GITLAB_BUILD_SYSTEM_NAME="Jenkins"
export GITLAB_BUILD_URL="http://localhost/jenkins/job/test/1"
./gitlab with_pipeline make build
```

Run command and comment result on merge request.
```sh
export GITLAB_MR_IID="3"
export GITLAB_MR_COMMENT_ON_START=":rocket: Build started."
export GITLAB_MR_COMMENT_ON_SUCCESS=":smile_cat: Build success."
export GITLAB_MR_COMMENT_ON_FAIL=":crying_cat_face: Build failed."
./gitlab with_merge_request_comment make build
```

Pipeline & Comment
```sh
export GITLAB_COMMIT_SHA="43127becfba9ffdc52715c006c1d36eeef8fb8ef"
export GITLAB_BUILD_SYSTEM_NAME="Jenkins"
export GITLAB_BUILD_URL="http://localhost/jenkins/job/test/1"
export GITLAB_MR_IID="3"
export GITLAB_MR_COMMENT_ON_START=":rocket: Build started."
export GITLAB_MR_COMMENT_ON_SUCCESS=":smile_cat: Build success."
export GITLAB_MR_COMMENT_ON_FAIL=":crying_cat_face: Build failed."
./gitlab with_pipeline ./gitlab with_merge_request_comment make build
```

Run command and send slack message.
```sh
export SLACK_API_TOKEN="your token"
export SLACK_CHANNEL="general"
export SLACK_MESSAGE_ON_SUCCESS=":smile_cat: Success"
export SLACK_MESSAGE_ON_FAIL=":crying_cat_face: Fail"
./slack with_message make build
```

Get slack user id from commit log.
```sh
export SLACK_API_TOKEN="your token"
./slack email2userid "$(git log -1 --pretty=format:'%ae')"
```
