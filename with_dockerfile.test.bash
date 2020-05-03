#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

if test -f /.dockerenv; then
  echo "warn: this test may not work on container, skip" >&${stdout}
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"


echo "case: show help message" >&${stdout}
# when:
./with_dockerfile --help | grep -qE "^Usage"


echo "case: error on unknown option" >&${stdout}
# when:
out=$(./with_dockerfile --no-such-option) || exit_status=$?
# then:
test "$exit_status" -ne 0
echo "$out" | grep -qE "^error: unknown option --no-such-option"


echo "case: container can read stdin" >&${stdout}
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
out=$(./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test cat <<< "hello")
# then:
test "$out" = "hello"


echo "case: default image name is directory name" >&${stdout}
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
docker image rm with_dockerfile_test:latest || true
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test true
# then:
docker image inspect with_dockerfile_test:latest


echo "case: copy artifact on exit" >&${stdout}
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test \
  --task-id 'ls' --artifact out.txt sh -c 'ls -lh > out.txt'
# then:
test -f ./artifacts/ls/out.txt


echo "case: use docker volume as cache" >&${stdout}
# given:
docker volume rm with-dockerfile-test-npm-user-cache || true
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM node:current-alpine" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test \
  --run-opts '--volume with-dockerfile-test-npm-user-cache:/root/.npm' \
  npm install --global ramda
# then:
docker run --rm --volume with-dockerfile-test-npm-user-cache:/root/.npm --workdir /root/.npm \
  busybox ls


echo "case: specify image name" >&${stdout}
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
docker image rm with_dockerfile_test_specify_name:dev || true
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test --image-name with_dockerfile_test_specify_name:dev true
# then:
docker image rm with_dockerfile_test_specify_name:dev


echo "case: remove image on exit" >&${stdout}
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test --remove-image-on-exit true
# then:
docker image inspect with_dockerfile_test:latest || exit_status=$?
test "$exit_status" -ne 0
