# YAML Compilation Pipeline
SHELL = /bin/sh

# Installation
BUILD = ./build
BINTARGET = $(BUILD)/bin/pawel-yaml

SRC_MAKE = $(MAKE) -C src \
	BUILD_ROOT="$(abspath $(BUILD))"

all: $(BINTARGET)

$(BINTARGET):
	@$(SRC_MAKE) all

directories:
	@$(SRC_MAKE) directories

lex:
	@$(SRC_MAKE) lex

# Testing
check: $(BINTARGET)
	./$< < test.yaml > /dev/null
	@echo "✓ Basic sanity check passed"

setup: ensure-test-failures yaml-test-suite
	@echo "✓ Setup complete (harness prerequisites ready)"

ensure-test-failures:
	@test -f TEST_FAILURES.yaml || { \
		echo "ERROR: TEST_FAILURES.yaml is missing"; \
		exit 1; \
	}

yaml-test-suite:
	@mkdir -p build/lib
	@if [ ! -d build/lib/yaml-test-suite/src ]; then \
		echo "Installing yaml-test-suite into build/lib/yaml-test-suite"; \
		if [ -d build/lib/yaml-test-suite/.git ]; then \
			git -C build/lib/yaml-test-suite pull --ff-only; \
		else \
			git clone --depth 1 https://github.com/yaml/yaml-test-suite.git build/lib/yaml-test-suite; \
		fi; \
	fi
	@test -d build/lib/yaml-test-suite/src || { \
		echo "ERROR: yaml-test-suite not available at build/lib/yaml-test-suite/src"; \
		echo "Run: git clone https://github.com/yaml/yaml-test-suite.git build/lib/yaml-test-suite"; \
		exit 1; \
	}
	@ls build/lib/yaml-test-suite/src/*.yaml >/dev/null 2>&1 || { \
		echo "ERROR: yaml-test-suite source directory exists but contains no *.yaml test files"; \
		exit 1; \
	}

fuzz-lexer: $(BINTARGET)
	ITERATIONS=$${ITERATIONS:-300} TIMEOUT_SEC=$${TIMEOUT_SEC:-2} ./lexer_fuzz_chaos.sh $${SEED:-1337}

fuzz-lexer-strict: $(BINTARGET)
	ITERATIONS=$${ITERATIONS:-300} TIMEOUT_SEC=$${TIMEOUT_SEC:-2} FAIL_ON_TIMEOUT=1 ./lexer_fuzz_chaos.sh $${SEED:-1337}

fuzz-lexer-replay: $(BINTARGET)
	TIMEOUT_SEC=$${TIMEOUT_SEC:-2} MODE=replay REPLAY_PATH=$${REPLAY_PATH:-build/log/lexer_fuzz_cases} ./lexer_fuzz_chaos.sh replay

fuzz-lexer-replay-strict: $(BINTARGET)
	TIMEOUT_SEC=$${TIMEOUT_SEC:-2} FAIL_ON_TIMEOUT=1 FAIL_ON_AMBIGUOUS=1 MODE=replay REPLAY_PATH=$${REPLAY_PATH:-build/log/lexer_fuzz_cases} ./lexer_fuzz_chaos.sh replay

# Cleanup
clean:
	@$(SRC_MAKE) clean
	@mkdir -p $(BUILD)
	rm -rf $(BUILD)/log $(BUILD)/tmp

.PHONY: all directories check clean lex fuzz-lexer fuzz-lexer-strict fuzz-lexer-replay fuzz-lexer-replay-strict
.PHONY: setup ensure-test-failures yaml-test-suite
