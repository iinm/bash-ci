#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

api_port=8080
export GITHUB_BASE_URL=http://localhost:$api_port
export GITHUB_TOKEN=test-token
export GITHUB_REPO=iinm/bash-ci


echo "case: show help message" >&${stdout}
# when:
./with_github_checks --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_github_checks --no-such-option) || exit_status=$?
# then:
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: command success" >&${stdout}
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -q "pending"
  echo "$req2" | grep -q "success"
) &
request_validator_pid=$!
# when:
./with_github_checks --commit-sha 777 --context "Bash" --build-url "http://localhost" \
  echo "Hello"
# then:
wait "$request_validator_pid"


echo "case: command failed" >&${stdout}
(
  # given:
  req1=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  req2=$(echo -e "HTTP/1.1 200 OK" | busybox nc -l -p "$api_port")
  # then:
  echo "$req1" | grep -q "pending"
  echo "$req2" | grep -q "failure"
) &
request_validator_pid=$!
# when:
./with_github_checks --commit-sha 777 --context "Bash" --build-url "http://localhost" \
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
  echo "$req1" | grep -q "pending"
  echo "$req2" | grep -q "failure"
) &
request_validator_pid=$!
# when:
./with_github_checks --commit-sha 777 --context "Bash" --build-url "http://localhost" \
  sleep 5 &
pid=$!
sleep 1
kill -s HUP "$pid"
wait "$pid" || exit_status=$?
# then:
test "$exit_status" -ne 0
wait "$request_validator_pid"
