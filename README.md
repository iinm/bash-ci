# Bash scripts for CI

![](https://github.com/iinm/bash-ci/workflows/verify/badge.svg?branch=master)


## Requirements

- [Bash](https://www.gnu.org/software/bash/)
- [cURL](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
- [Docker](https://www.docker.com/) (Optional)


## Docker

Run command on container. (Assume you have Dockerfile)
```sh
./with_dockerfile --verbose make lint
```

```sh
mkdir -p ./tmp/with_dockerfile_exmaple
echo "FROM busybox" > ./tmp/with_dockerfile_exmaple/Dockerfile

./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_exmaple ls -lh
```

Run command on container and copy artifacts from docker volume to host directory.
```sh
mkdir -p ./tmp/with_dockerfile_exmaple
echo "FROM busybox" > ./tmp/with_dockerfile_exmaple/Dockerfile

./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_exmaple \
  --task-id 'ls' --artifact out.txt sh -c 'ls -lh > out.txt'

cat ./artifacts/ls/out.txt
```

Use docker volume as cache.
```sh
mkdir -p ./tmp/with_dockerfile_exmaple
echo "FROM node:current-alpine" > ./tmp/with_dockerfile_exmaple/Dockerfile

./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_exmaple \
  --task-id 'node-example' --run-opts '-v npm-user-cache:/root/.npm' \
  sh -c 'npm install ramda; ls -lh ./node_modules'
```


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
./gitlab.bash list_merge_requests \
  | ./gitlab.bash hook_merge_requests --verbose \
    --logdir ./tmp \
    --hook-id hook_merge_requests_test \
    --filter '.labels | map(. == "skip-ci") | any | not'
    --cmd 'echo "[$MERGE_REQUEST_IID] $SOURCE_BRANCH -> $TARGET_BRANCH ($MERGE_REQUEST_URL)"' 
```

- `--logdir`  : stdout / stderr of cmd will be output this directory.
- `--hook-id` : Hook id must be unique. (Used as a part of log file name)
- `--filter`  : [jq](https://stedolan.github.io/jq/manual/) filter to select merge request to hook.
- `--cmd`     : Command you want to execute when merge request is created / updated.
  - Environment variables `$MERGE_REQUEST_IID`, `$SOURCE_BRANCH`, `$TARGET_BRANCH`, and `$MERGE_REQUEST_URL` are automatically set.

Trigger Jenkins job for merge request.
```sh
./gitlab.bash list_merge_requests \
  | ./gitlab.bash hook_merge_requests --verbose \
    --logdir ./tmp \
    --hook-id hook_merge_requests_test \
    --filter '.labels | map(. == "skip-ci") | any | not'
    --cmd 'curl -X POST -u $JENKINS_AUTH "http://localhost/job/test/build" -F json="$(./gitlab.bash merge_request_json_for_jenkins)"' 
```

Run command as GitLab Pipeline job.
```sh
./with_gitlab_pipeline --commit-sha "$(git log -n 1 --pretty=format:'%H')" \
  --build-system-name "Jenkins" --build-url "http://localhost/jenkins/job/test/1" \
  make lint test
```

Run command and comment result on merge request.
```sh
./with_gitlab_mr_comment --iid "3" \
  --comment-on-start ":rocket: Build started." \
  --comment-on-cancel ":crying_cat_face: Build canceled." \
  --comment-on-success ":smile_cat: Build success." \
  --comment-on-fail ":crying_cat_face: Build failed." \
  make lint test
```

Combine Pipeline & Comment
```sh
./with_gitlab_mr_comment --iid "3" \
  --comment-on-start ":rocket: Build started." \
  --comment-on-cancel ":crying_cat_face: Build canceled." \
  --comment-on-success ":smile_cat: Build success." \
  --comment-on-fail ":crying_cat_face: Build failed." \
  ./with_gitlab_pipeline --commit-sha "$(git log -n 1 --pretty=format:'%H')" \
    --build-system-name "Jenkins" --build-url "http://localhost/jenkins/job/test/1" \
    make lint test
```


## Slack

Set environment variables.
```sh
export SLACK_API_TOKEN="your token"
```

Run command and send Slack message.
```sh
./with_slack_message --channel "random" \
  --message-on-success ":smile_cat: Success" \
  --message-on-fail ":crying_cat_face: Fail" \
  make lint test
```

Get Slack user id from commit log.
```sh
./slack.bash email2userid "$(git log -1 --pretty=format:'%ae')"
```

Post text message.
```sh
./slack.bash post_text_message --channel "#random" --text "Hello!"
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


## Test Bash-CI

Requirements
- shellcheck
- busybox
- gawk

```sh
make lint test
```

or use Docker
```sh
bash ./with_dockerfile.test.bash 2> test.log
./with_dockerfile --verbose --task-id test --run-opts "--tty" --artifact test.log make lint test
```
