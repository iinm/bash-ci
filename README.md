# Bash scripts for GitLab

Motivations:
- I cannot use GitLab webhook in some environments for security reason.
- I like Jenkins, but I don't want to rely on complicated plugins which may break entire Jenkins.


## Merge Request Hook

Use case: Verify source code when merge request is created.

Usage:
```sh
env \
  GITLAB_BASE_URL=https://gitlab.com \
  GITLAB_PROJECT_ID=0000 \
  GITLAB_PRIVATE_TOKEN="your token" \
  ./merge_request_hook.bash ./example/merge_request_hooks ./example/hook_history
```

Example hook script:
```sh
#!/usr/bin/env bash

# filter: .labels[] | contains("test")

cat << EOS
request_id="$request_id"
request_iid="$request_iid"
source_branch="$source_branch"
target_branch="$target_branch"
EOS
```

- `# filter: ...` : This comment filters merge request to hook. See [jq manual](https://stedolan.github.io/jq/manual/).
- Some environment variables are automatically set.


## Merge Request Comment

Use case: Notify verification result.

Usage:
```sh
env \
  GITLAB_BASE_URL=https://gitlab.com \
  GITLAB_PROJECT_ID=0000 \
  GITLAB_PRIVATE_TOKEN="your token" \
  MERGE_REQUEST_IID="1" \
  COMMENT_ON_START=":rocket: Verification started." \
  COMMENT_ON_SUCCESS=":smile: LGTM\!" \
  COMMENT_ON_FAIL=":cry: Sorry, Something is wrong." \
  ./with_comment.bash make test
```
