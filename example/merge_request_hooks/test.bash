#!/usr/bin/env bash

# filter: .labels[] | contains("test")

cat << EOS
request_id="$request_id"
request_iid="$request_iid"
source_branch="$source_branch"
target_branch="$target_branch"
EOS
