SHELL = /bin/sh

ROOT := $(abspath ../..)
PARSER ?= $(ROOT)/build/bin/pawel-yaml
GIT ?= git
TIMEOUT_SEC ?= 3
TMP_DIR := $(ROOT)/build/tmp/grammar-loops

ALL_CASES := $(sort $(basename $(notdir $(wildcard cases/*.yaml))))
CASES := $(if $(CASE),$(CASE),$(ALL_CASES))

.PHONY: check check-one expect expect-all list clean

list:
	@for case_id in $(ALL_CASES); do \
		echo "$$case_id"; \
	done

check: check-one
	@:

check-one:
	@test -x "$(PARSER)" || { \
		echo "ERROR: parser not built at $(PARSER)"; \
		echo "Run: make"; \
		exit 1; \
	}
	@mkdir -p "$(TMP_DIR)"
	@set -e; \
	total=0; pass=0; fail=0; \
	for case_id in $(CASES); do \
		in_file="cases/$$case_id.yaml"; \
		exit_file="expected/$$case_id.exit"; \
		tok_file="expected/$$case_id.tokens"; \
		out_file="$(TMP_DIR)/$$case_id.stdout"; \
		err_file="$(TMP_DIR)/$$case_id.stderr"; \
		out_norm="$(TMP_DIR)/$$case_id.stdout.norm"; \
		diff_file="$(TMP_DIR)/$$case_id.diff"; \
		total=$$((total + 1)); \
		if [ ! -f "$$in_file" ]; then \
			echo "FAIL: $$case_id (missing $$in_file)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		if [ ! -f "$$exit_file" ]; then \
			echo "FAIL: $$case_id (missing $$exit_file)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		if [ ! -f "$$tok_file" ]; then \
			echo "FAIL: $$case_id (missing $$tok_file)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		if timeout "$(TIMEOUT_SEC)" "$(PARSER)" -dump-tokens < "$$in_file" > "$$out_file" 2> "$$err_file"; then \
			rc=0; \
		else \
			rc=$$?; \
		fi; \
		exp_rc=$$(cat "$$exit_file"); \
		if [ "$$rc" -ne "$$exp_rc" ]; then \
			echo "FAIL: $$case_id (exit $$rc != expected $$exp_rc)"; \
			if [ -s "$$err_file" ]; then \
				head -1 "$$err_file" | sed 's/^/      /'; \
			elif [ "$$rc" -eq 124 ]; then \
				echo "      timeout after $(TIMEOUT_SEC)s"; \
			fi; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		sed '/^[[:space:]]*$$/d' "$$out_file" > "$$out_norm.tmp"; \
		mv "$$out_norm.tmp" "$$out_norm"; \
		if ! $(GIT) --no-pager diff --no-index -- "$$tok_file" "$$out_norm" > "$$diff_file"; then \
			echo "FAIL: $$case_id (token mismatch)"; \
			sed -n '1,80p' "$$diff_file" | sed 's/^/      /'; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		echo "PASS: $$case_id"; \
		pass=$$((pass + 1)); \
	done; \
	echo "Grammar-loop suite: $$pass/$$total passed"; \
	test "$$fail" -eq 0

expect:
	@test -n "$(CASE)" || { \
		echo "Usage: make -C tests/grammar-loops expect CASE=<case-id>"; \
		exit 1; \
	}
	@test -x "$(PARSER)" || { \
		echo "ERROR: parser not built at $(PARSER)"; \
		echo "Run: make"; \
		exit 1; \
	}
	@test -f "cases/$(CASE).yaml" || { \
		echo "ERROR: missing case file cases/$(CASE).yaml"; \
		exit 1; \
	}
	@mkdir -p expected "$(TMP_DIR)"
	@set -e; \
	out_file="$(TMP_DIR)/$(CASE).stdout"; \
	err_file="$(TMP_DIR)/$(CASE).stderr"; \
	if timeout "$(TIMEOUT_SEC)" "$(PARSER)" -dump-tokens < "cases/$(CASE).yaml" > "$$out_file" 2> "$$err_file"; then \
		rc=0; \
	else \
		rc=$$?; \
	fi; \
	printf "%s\n" "$$rc" > "expected/$(CASE).exit"; \
	sed '/^[[:space:]]*$$/d' "$$out_file" > "expected/$(CASE).tokens"; \
	echo "Updated expected/$(CASE).exit and expected/$(CASE).tokens"; \
	$(GIT) --no-pager diff -- "expected/$(CASE).exit" "expected/$(CASE).tokens" || true

expect-all:
	@for case_id in $(ALL_CASES); do \
		$(MAKE) expect CASE="$$case_id"; \
	done

clean:
	rm -rf "$(TMP_DIR)"
