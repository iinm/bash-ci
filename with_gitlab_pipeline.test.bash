#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITLAB_BASE_URL=http://localhost:$api_port
export GITLAB_PRIVATE_TOKEN=test-token
export GITLAB_PROJECT_ID=001


echo "case: show help message" >&${stdout}
# when:
./with_gitlab_pipeline --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_gitlab_pipeline --no-such-option) || exit_status=$?
# then:
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: command success" >&${stdout}
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
  echo "Hello"
# then:
wait "$request_validator_pid"


echo "case: command failed" >&${stdout}
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
./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  false || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"


echo "case: command canceled" >&${stdout}
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
  sleep 5 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
