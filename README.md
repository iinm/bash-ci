# Bash scripts for CI

## Use case

- Run command (e.g. start Jenkins job) and verify source code when merge request is created.
  - Note that you need job management system because scripts below don't manage job execution.
- Run verification command as external pipeline job on GitLab, and comment result on merge request.


## Requirements

- Bash
- cURL
- jq


## GitLab

Set environment variables.
```sh
export GITLAB_BASE_URL="https://gitlab.com"
export GITLAB_PRIVATE_TOKEN="your token"   # https://gitlab.com/profile/personal_access_tokens
export GITLAB_PROJECT_ID="your project id"
```

List merge requests.
```sh
# List opened MR (default)
./gitlab_cli list_merge_requests | jq .

# Filter by date
./gitlab_cli list_merge_requests | jq "map(select(.updated_at > \"2019-09-23T09:00:00.000Z\"))"
```

Run command when merge request is created / updated.
```sh
hooks=$(cat << 'EOF'
[
  {
    "id": "test",
    "filter": ".labels[] | contains(\"test\")",
    "cmd": "echo \"id: $MERGE_REQUEST_IID source: $SOURCE_BRANCH -> target: $TARGET_BRANCH ($MERGE_REQUEST_URL)\""
  },
  {
    "id": "test-jenkins",
    "filter": ".labels[] | contains(\"jenkins-test\")",
    "cmd": "curl -X POST -u $JENKINS_AUTH \"http://localhost/jenkins/job/test/buildWithParameters?SOURCE_BRANCH=$SOURCE_BRANCH&TARGET_BRANCH=$TARGET_BRANCH&MERGE_REQUEST_IID=$MERGE_REQUEST_IID\""
  }
]
EOF
)

./gitlab_cli list_merge_requests \
  | env GITLAB_MR_HOOK_LOGDIR=hook_log ./gitlab_cli hook_merge_requests <(echo "$hooks")
```

- `filter` : [jq](https://stedolan.github.io/jq/manual/) filter to select merge request to hook.
- `cmd` : Command you want to execute when merge request is created / updated.
  - Environment variables `$MERGE_REQUEST_IID`, `$SOURCE_BRANCH`, `$TARGET_BRANCH`, and `$MERGE_REQUEST_URL` are automatically set.


Run command as GitLab Pipeline job.
```sh
env GITLAB_COMMIT_SHA="43127becfba9ffdc52715c006c1d36eeef8fb8ef" \
    GITLAB_BUILD_SYSTEM_NAME="Jenkins" \
    GITLAB_BUILD_URL="http://localhost/jenkins/job/test/1" \
    ./with_gitlab_pipeline make lint
```

Run command and comment result on merge request.
```sh
env GITLAB_MR_IID="3" \
    GITLAB_MR_COMMENT_ON_START=":rocket: Build started." \
    GITLAB_MR_COMMENT_ON_SUCCESS=":smile_cat: Build success." \
    GITLAB_MR_COMMENT_ON_FAIL=":crying_cat_face: Build failed." \
    GITLAB_MR_COMMENT_ON_CANCEL=":crying_cat_face: Build canceled." \
    ./with_gitlab_mr_comment make lint
```

Combine Pipeline & Comment
```sh
env GITLAB_COMMIT_SHA="43127becfba9ffdc52715c006c1d36eeef8fb8ef" \
    GITLAB_BUILD_SYSTEM_NAME="Jenkins" \
    GITLAB_BUILD_URL="http://localhost/jenkins/job/test/1" \
    GITLAB_MR_IID="3" \
    GITLAB_MR_COMMENT_ON_START=":rocket: Build started." \
    GITLAB_MR_COMMENT_ON_SUCCESS=":smile_cat: Build success." \
    GITLAB_MR_COMMENT_ON_FAIL=":crying_cat_face: Build failed." \
    GITLAB_MR_COMMENT_ON_CANCEL=":crying_cat_face: Build canceled." \
    ./with_gitlab_pipeline ./with_gitlab_mr_comment make lint
```


## Slack

Set environment variables.
```sh
export SLACK_API_TOKEN="your token"
```

Run command and send Slack message.
```sh
env SLACK_CHANNEL="general" \
    SLACK_MESSAGE_ON_SUCCESS=":smile_cat: Success" \
    SLACK_MESSAGE_ON_FAIL=":crying_cat_face: Fail" \
    ./with_slack_message make lint
```

Get Slack user id from commit log.
```sh
./slack_cli email2userid "$(git log -1 --pretty=format:'%ae')"
```
