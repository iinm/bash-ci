# Bash scripts for CI

## Use case

- Verify source code when merge request is created.
  - Note that you need job queue like [Task Spooler](https://vicerveza.homeunix.net/~viric/soft/ts/).
- Run verification command as external pipeline job on GitLab, and comment result on merge request.


## Requirements

- [Bash](https://www.gnu.org/software/bash/)
- [cURL](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)


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
./gitlab.bash list_merge_requests | jq .

# Filter by date
./gitlab.bash list_merge_requests | jq "map(select(.updated_at > \"2019-09-23T09:00:00.000Z\"))"
```

Run command when merge request is created / updated.
```sh
cat << 'EOF' > ./hooks.json
[
  {
    "id": "test",
    "filter": ".labels | map(. == \"skip-ci\") | any | not",
    "cmd": "echo \"id: $MERGE_REQUEST_IID source: $SOURCE_BRANCH -> target: $TARGET_BRANCH ($MERGE_REQUEST_URL)\""
  },
  {
    "id": "jenkins-test",
    "filter": ".labels | map(. == \"jenkins-test\") | any",
    "cmd": "curl -X POST -u $JENKINS_AUTH 'http://localhost/job/test/build' -F json=\"$(./gitlab.bash merge_request_json_for_jenkins)\""
  },
  {
    "id": "ts-test",
    "filter": ".labels | map(. == \"jenkins-test\") | any",
    "cmd": "tsp make lint"
  }
]
EOF

./gitlab.bash list_merge_requests \
  | env GITLAB_MR_HOOK_LOGDIR=./hook_log ./gitlab.bash hook_merge_requests ./hooks.json
```

- `id` : Hook id must be unique.
- `filter` : [jq](https://stedolan.github.io/jq/manual/) filter to select merge request to hook.
- `cmd` : Command you want to execute when merge request is created / updated.
  - Environment variables `$MERGE_REQUEST_IID`, `$SOURCE_BRANCH`, `$TARGET_BRANCH`, and `$MERGE_REQUEST_URL` are automatically set.


Run command as GitLab Pipeline job.
```sh
env GITLAB_COMMIT_SHA="$(git log -n 1 --pretty=format:'%H')" \
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
env GITLAB_COMMIT_SHA="$(git log -n 1 --pretty=format:'%H')" \
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
./slack.bash email2userid "$(git log -1 --pretty=format:'%ae')"
```

Post text message.
```sh
./slack.bash post_text_message "#random" "Hello!"
```

Post message.
```sh
./slack.bash post_message << EOF
{
  "as_user": false,
  "username": "Bot",
  "icon_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/GNOME_Builder_Icon_%28hicolor%29.svg/240px-GNOME_Builder_Icon_%28hicolor%29.svg.png",
  "channel": "general",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": ":smile_cat: Build success!"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*<https://google.com|GitLab MR>*"
        },
        {
          "type": "mrkdwn",
          "text": "*<https://google.com|Jenkins>*"
        }
      ]
    }
  ]
}
EOF
```
