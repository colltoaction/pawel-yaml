SHELL = /bin/sh

ROOT := $(abspath ..)
SCRIPTS := $(ROOT)/tests/legacy/scripts
DETECT_ISSUES_TIMEOUT ?= 5.0
DETECT_ISSUES_WALL_TIMEOUT ?= 900
MAKE_WALL_TIMEOUT ?= 1200

.PHONY: help build setup check grammar-loops grammar-loops-expect grammar-loops-expect-all
.PHONY: discover test detect-issues runner update-failures verify-fast verify-full tooling

help:
	@echo "Consolidated test entry points"
	@echo "  make -C tests build"
	@echo "  make -C tests setup"
	@echo "  make -C tests check"
	@echo "  make -C tests grammar-loops [CASE=<case-id>]"
	@echo "  make -C tests grammar-loops-expect CASE=<case-id>"
	@echo "  make -C tests grammar-loops-expect-all"
	@echo "  make -C tests discover"
	@echo "  make -C tests test TEST=<ID>"
	@echo "  make -C tests detect-issues TEST='<ID1 ID2>'"
	@echo "  make -C tests runner [TEST='<ID1 ID2>']"
	@echo "  make -C tests update-failures"
	@echo "  make -C tests verify-fast"
	@echo "  make -C tests verify-full"
	@echo "  make -C tests tooling CMD='<tooling-subcommand>'"

build:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT) all; \
	else \
		$(MAKE) -C $(ROOT) all; \
	fi

setup:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT) setup; \
	else \
		$(MAKE) -C $(ROOT) setup; \
	fi

check:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT) check; \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT)/tests grammar-loops; \
	else \
		$(MAKE) -C $(ROOT) check; \
		$(MAKE) -C $(ROOT)/tests grammar-loops; \
	fi

grammar-loops: build
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT)/tests/grammar-loops check $(if $(CASE),CASE=$(CASE),); \
	else \
		$(MAKE) -C $(ROOT)/tests/grammar-loops check $(if $(CASE),CASE=$(CASE),); \
	fi

grammar-loops-expect:
	@test -n "$(CASE)" || { echo "Usage: make -C tests grammar-loops-expect CASE=<case-id>"; exit 1; }
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT)/tests/grammar-loops expect CASE="$(CASE)"; \
	else \
		$(MAKE) -C $(ROOT)/tests/grammar-loops expect CASE="$(CASE)"; \
	fi

grammar-loops-expect-all:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(MAKE) -C $(ROOT)/tests/grammar-loops expect-all; \
	else \
		$(MAKE) -C $(ROOT)/tests/grammar-loops expect-all; \
	fi

discover:
	@cd $(ROOT) && $(SCRIPTS)/tdd_harness.sh discover

test:
	@test -n "$(TEST)" || { echo "Usage: make -C tests test TEST=<ID>"; exit 1; }
	@cd $(ROOT) && $(SCRIPTS)/tdd_harness.sh test "$(TEST)"

detect-issues:
	@cd $(ROOT) && \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(DETECT_ISSUES_WALL_TIMEOUT)s \
			python3 $(SCRIPTS)/detect_issues.py --timeout=$(DETECT_ISSUES_TIMEOUT) --max-total-seconds=$(DETECT_ISSUES_WALL_TIMEOUT) $(foreach tid,$(TEST),--test $(tid)); \
	else \
		python3 $(SCRIPTS)/detect_issues.py --timeout=$(DETECT_ISSUES_TIMEOUT) --max-total-seconds=$(DETECT_ISSUES_WALL_TIMEOUT) $(foreach tid,$(TEST),--test $(tid)); \
	fi

runner:
	@cd $(ROOT) && python3 $(SCRIPTS)/test_runner.py $(foreach tid,$(TEST),--test $(tid))

update-failures:
	@cd $(ROOT) && python3 $(SCRIPTS)/test_runner.py --update

verify-fast: build
	@cd $(ROOT) && $(SCRIPTS)/verify_suite_fast.sh

verify-full: build
	@cd $(ROOT) && $(SCRIPTS)/verify_full_suite.sh

tooling:
	@test -n "$(CMD)" || { echo "Usage: make -C tests tooling CMD='<subcommand>' [ARGS='...']"; exit 1; }
	@cd $(ROOT) && $(SCRIPTS)/tooling.sh $(CMD) $(ARGS)
