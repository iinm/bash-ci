#!/usr/bin/env bash

set -eu -o pipefail

help() {
  cat << HELP
Usage: run_tests.bash [--logfile FILE] TEST_SCRIPT...
HELP
}

while test "$#" -gt 0; do
  case "$1" in
    --help    ) help; exit 0 ;;
    --logfile ) logfile=$2; shift 2 ;;
    *         ) break;
  esac
done

: "${logfile:=test.log}"
if test "$#" -eq 0; then
  help >&2
  exit 1
fi

echo > "$logfile"
exit_status=0
for file in "$@"; do
  echo -e "\n$(tput setaf 4)test: $file$(tput sgr0)"
  if bash -x "$file" 2>> "$logfile"; then
    echo "$(tput setaf 2)all case passed$(tput sgr0)"
  else
    exit_status=$?
    echo "$(tput setaf 1)failed$(tput sgr0)"
    tac "$logfile" | grep -B 1000 -m 1 "+ echo 'case:" | tac
  fi
done

exit "$exit_status"
