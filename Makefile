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
	find . -name '*.test.bash' \
		| xargs -n 1 -I {} bash -c "echo -e '\n$(shell tput setaf 4)run: {}$(shell tput sgr0)'; (bash -x {} && echo '$(shell tput setaf 2)all case passed$(shell tput sgr0)') || (echo '$(shell tput setaf 1)failed$(shell tput sgr0)'; tac test.log | grep -B 1000 -m 1 \"+ echo 'case:\" | tac; exit 1)" 2> test.log
