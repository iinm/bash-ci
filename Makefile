scripts := $(shell grep -lr '\#!/usr/bin/env bash' | grep -v Makefile)

.PHONY: all
all: ;

.PHONY: lint
lint:
	shellcheck -x $(scripts)
