.PHONY: check

all: research

RESEARCH_PROMPTS := AGENTIC_TDD.prompt.md COMPUTING_INSPIRATION.prompt.md YACC.prompt.md
research: $(RESEARCH_PROMPTS)

# ==============================================================================
# Workflow Verification
# ==============================================================================
check:
	@echo "Verifying TDD status..."
	./tdd_harness.sh discover | head -20

# ==============================================================================
# Prompt the agent explicitly
# ==============================================================================
%.md: %.prompt.md
	cat $<
	cat > $@

%.yaml: %.prompt.yaml
# 	1. ensure prompt parses as valid YAML and then print
	@echo "Continue until fixpoint"
	@echo "---"
	@cat $@ 2>/dev/null || echo ""
	@echo "---"
	@cat $<
# 	2. ensure response parses as valid YAML
	@while true; do \
		cat - > $@.tmp; \
		if [ ! -s $@.tmp ]; then rm $@.tmp; break; fi; \
		if ../build/bin/pawel-yaml -ast-dump < $@.tmp; then \
			mv $@.tmp $@; \
			break; \
		else \
			echo "no es yaml!!!"; \
		fi; \
	done
