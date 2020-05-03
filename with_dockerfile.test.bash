#!/usr/bin/env bash

set -eu -o pipefail

if test -f /.dockerenv; then
  echo "warn: this test may not work on container, skip"
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"


echo "case: show help message"
./with_dockerfile --help | grep -qE "^Usage"


echo "case: container can read stdin"
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
out=$(./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test cat <<< "hello")
test "$out" = "hello"


echo "case: default image name is directory name"
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test true
# then:
docker image inspect with_dockerfile_test:latest >&2


echo "case: copy artifact on exit"
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test \
  --task-id 'ls' --artifact out.txt sh -c 'ls -lh > out.txt'
# then:
test -f ./artifacts/ls/out.txt


echo "case: use docker volume as cache"
# given:
docker volume rm with-dockerfile-test-npm-user-cache >&2|| true
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM node:current-alpine" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test \
  --run-opts '--volume with-dockerfile-test-npm-user-cache:/root/.npm' \
  npm install --global ramda >&2
# then:
docker run --rm --volume with-dockerfile-test-npm-user-cache:/root/.npm --workdir /root/.npm \
  busybox ls >&2


echo "case: specify image name"
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test --image-name with_dockerfile_test_specify_name:dev true
# then:
docker image rm with_dockerfile_test_specify_name:dev >&2


echo "case: remove image on exit"
# given:
rm -rf ./tmp && mkdir -p ./tmp/with_dockerfile_test
echo "FROM busybox" > ./tmp/with_dockerfile_test/Dockerfile
# when:
./with_dockerfile --verbose --build-path ./tmp/with_dockerfile_test --remove-image-on-exit true
# then:
if docker image inspect with_dockerfile_test:latest > /dev/null; then
  echo "error: image should be removed" >&2
  exit 1
fi
