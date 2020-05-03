#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: show help message"
# when:
./with_gitlab_pipeline --help | grep -qE "^Usage"


echo "case: error on unknown option"
# when:
if out=$(./with_gitlab_pipeline --no-such-option); then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: command success"
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req2" | grep -qE "^state=success&name=Bash&target_url=http://localhost"
) &
request_validator_pid=$!
# when:
./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  echo "Hello" >&2
# then:
wait "$request_validator_pid"


echo "case: command failed"
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req2" | grep -qE "^state=failed&name=Bash&target_url=http://localhost"
) &
request_validator_pid=$!
# when:
if ./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  false >&2; then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
wait "$request_validator_pid"


echo "case: command canceled"
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  echo "$req2" | grep -qE "^state=canceled&name=Bash&target_url=http://localhost"
) &
request_validator_pid=$!
# when:
./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  sleep 5 >&2 &
pid=$!
sleep 1
kill -s HUP "$pid"
if wait "$pid"; then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
wait "$request_validator_pid"
