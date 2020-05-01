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


echo "case: command success"
# given:
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=success&name=Bash&target_url=http://localhost"
) &
# when:
./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  echo "Hello" >&2
# then:
wait "$(jobs -p)"


echo "case: command failed"
# given:
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=failed&name=Bash&target_url=http://localhost"
) &
# when:
if ./with_gitlab_pipeline --commit-sha 777 --build-system-name "Bash" --build-url "http://localhost" \
  false >&2; then
  echo "error: command should fail" >&2
  exit 1
fi
# then:
wait "$(jobs -p)"


echo "case: command canceled"
# given:
(
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=running&name=Bash&target_url=http://localhost"
  req=$(echo -e "HTTP/1.1 200 OK\n\nOK" | busybox nc -l -p "$api_port")
  echo "$req" | grep -qE "^state=canceled&name=Bash&target_url=http://localhost"
) &
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
wait "$(jobs -p)"
