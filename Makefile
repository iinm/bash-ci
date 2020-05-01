scripts := $(shell grep -lr '\#!/usr/bin/env bash' . | grep -v Makefile)

.PHONY: all
all: ;

.PHONY: lint
lint:
	shellcheck -x $(scripts)

.PHONY: test
test:
	find . -name '*.test.bash' \
		| xargs -n 1 -I {} sh -c "echo -e '\n$(shell tput setaf 4)test: {}$(shell tput sgr0)'; bash -x {} && echo '$(shell tput setaf 2)all case passed$(shell tput sgr0)' || echo '$(shell tput setaf 1)failed$(shell tput sgr0)'" \
		2> test.log
