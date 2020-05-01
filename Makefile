scripts := $(shell grep -lr '\#!/usr/bin/env bash' . | grep -v Makefile)

.PHONY: all
all: ;

.PHONY: lint
lint:
	shellcheck -x $(scripts)

.PHONY: test
test:
	find . -name '*.test.bash' \
		| xargs -n 1 -I {} sh -c "echo -e '\ntest: {}'; bash -x {}" 2> test.log
