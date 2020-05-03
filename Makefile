.DEFAULT_GOAL := help

scripts := $(shell grep -lr '\#!/usr/bin/env bash' . | grep -v Makefile)


.PHONY: help
## help | show help
help:
	@grep -E '^##' $(MAKEFILE_LIST) \
		| sed -E 's,##\s*,,' \
		| column -s '|' -t \
		| sed -E "s,^([^ ]+),$(shell tput setaf 6)\1$(shell tput sgr0),"


.PHONY: lint
## lint | run shellcheck
lint:
	$(info $(shell tput setaf 6)--- $@$(shell tput sgr0))
	shellcheck -x $(scripts)


.PHONY: test
## test | run test
test:
	$(info $(shell tput setaf 6)--- $@$(shell tput sgr0))
	./run_tests.bash *.test.bash
