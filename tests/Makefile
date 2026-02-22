SHELL = /bin/sh

ROOT := $(abspath ..)
SCRIPTS := $(ROOT)/tests/legacy/scripts

.PHONY: help build setup check discover test detect-issues runner update-failures verify-fast verify-full tooling

help:
	@echo "Consolidated test entry points"
	@echo "  make -C tests build"
	@echo "  make -C tests setup"
	@echo "  make -C tests check"
	@echo "  make -C tests discover"
	@echo "  make -C tests test TEST=<ID>"
	@echo "  make -C tests detect-issues TEST='<ID1 ID2>'"
	@echo "  make -C tests runner [TEST='<ID1 ID2>']"
	@echo "  make -C tests update-failures"
	@echo "  make -C tests verify-fast"
	@echo "  make -C tests verify-full"
	@echo "  make -C tests tooling CMD='<tooling-subcommand>'"

build:
	@$(MAKE) -C $(ROOT) all

setup:
	@$(MAKE) -C $(ROOT) setup

check:
	@$(MAKE) -C $(ROOT) check

discover:
	@cd $(ROOT) && $(SCRIPTS)/tdd_harness.sh discover

test:
	@test -n "$(TEST)" || { echo "Usage: make -C tests test TEST=<ID>"; exit 1; }
	@cd $(ROOT) && $(SCRIPTS)/tdd_harness.sh test "$(TEST)"

detect-issues:
	@cd $(ROOT) && python3 $(SCRIPTS)/detect_issues.py $(foreach tid,$(TEST),--test $(tid))

runner:
	@cd $(ROOT) && python3 $(SCRIPTS)/test_runner.py $(foreach tid,$(TEST),--test $(tid))

update-failures:
	@cd $(ROOT) && python3 $(SCRIPTS)/test_runner.py --update

verify-fast:
	@cd $(ROOT) && $(SCRIPTS)/verify_suite_fast.sh

verify-full:
	@cd $(ROOT) && $(SCRIPTS)/verify_full_suite.sh

tooling:
	@test -n "$(CMD)" || { echo "Usage: make -C tests tooling CMD='<subcommand>' [ARGS='...']"; exit 1; }
	@cd $(ROOT) && $(SCRIPTS)/tooling.sh $(CMD) $(ARGS)
