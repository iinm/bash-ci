#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

echo "case: show help message"
./git.bash has_remote_update --help | grep -qE '^Usage:'
