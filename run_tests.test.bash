#!/usr/bin/env bash

set -eu -o pipefail

exec {stdout}>&1 1>&2

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$script_dir"


echo "case: show help message" >&${stdout}
./run_tests.bash --help | grep -qE "^Usage"


echo "case: test success" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/success.test.bash << 'SCRIPT'
echo "case: success"
test 1 -eq 1 >&2
SCRIPT
# when:
out=$(./run_tests.bash --logfile ./tmp/success-test.log ./tmp/*.test.bash)
# then:
expected=$(cat << EXPECTED

$(tput setaf 4)test: ./tmp/success.test.bash$(tput sgr0)
case: success
$(tput setaf 2)all case passed$(tput sgr0)
EXPECTED
)
diff -u <(echo "$expected") <(echo "$out")
# then:
grep -q "+ echo 'case: success'" ./tmp/success-test.log


echo "case: test fail" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/fail.test.bash << 'SCRIPT'
echo "case: fail"
test 1 -eq 2 >&2
SCRIPT
# when:
out=$(./run_tests.bash --logfile ./tmp/fail-test.log ./tmp/*.test.bash) || exit_status=$?
# then:
test "$exit_status" -ne 0
expected=$(cat << EXPECTED

$(tput setaf 4)test: ./tmp/fail.test.bash$(tput sgr0)
case: fail
$(tput setaf 1)failed$(tput sgr0)
+ echo 'case: fail'
+ test 1 -eq 2
EXPECTED
)
diff -u <(echo "$expected") <(echo "$out")
# then:
grep -q "+ echo 'case: fail'" ./tmp/fail-test.log


echo "case: run all scripts but fail if any test fail" >&${stdout}
# given:
rm -rf ./tmp && mkdir ./tmp
cat > ./tmp/success.test.bash << 'SCRIPT'
echo "case: success"
test 1 -eq 1 >&2
SCRIPT
cat > ./tmp/fail.test.bash << 'SCRIPT'
echo "case: fail"
test 1 -eq 2 >&2
SCRIPT
# when:
out=$(./run_tests.bash --logfile ./tmp/fail-test.log ./tmp/{fail,success}.test.bash) || exit_status=$?
# then:
test "$exit_status" -ne 0
expected=$(cat << EXPECTED

$(tput setaf 4)test: ./tmp/fail.test.bash$(tput sgr0)
case: fail
$(tput setaf 1)failed$(tput sgr0)
+ echo 'case: fail'
+ test 1 -eq 2

$(tput setaf 4)test: ./tmp/success.test.bash$(tput sgr0)
case: success
$(tput setaf 2)all case passed$(tput sgr0)
EXPECTED
)
diff -u <(echo "$expected") <(echo "$out")
# then:
grep -q "+ echo 'case: success'" ./tmp/fail-test.log
grep -q "+ echo 'case: fail'" ./tmp/fail-test.log
