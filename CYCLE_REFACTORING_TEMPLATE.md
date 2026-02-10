# CYCLE {{CYCLE_NUM}} REFACTORING GUIDE: {{TITLE}}

**Branch**: {{BRANCH}}  
**Target File(s)**: {{TARGET_FILES}}  
**Scope**: {{SCOPE}}  
**Lines Total**: {{LINES_TOTAL}}  
**Risk Level**: {{RISK_LEVEL}}  
**Estimated Time**: {{ESTIMATED_TIME}}

---

## SITUATION

{{SITUATION_TEXT}}

---

## WHAT TO REFACTOR

{{REFACTORING_OPPORTUNITIES}}

### Success Goal
**Reduce by {{TARGET_REDUCTION}} lines** while:
- Maintaining all functionality  
- Keeping behavior identical
- Improving code clarity

---

## TDD PROTOCOL

### RED PHASE (Establish Baseline)
```bash
cd /home/widip/titi-org/pawel-yaml
git status  # Confirm on {{BRANCH}}
make clean && make
echo "BUILD: $?"

# Record baseline metrics
wc -l {{TARGET_FILES}}
stat -c%s build/bin/pawel-yaml
{{BASELINE_COMMANDS}}
```

### GREEN PHASE (Code Review & Planning)
{{GREEN_PHASE_STEPS}}

### REFACTOR PHASE (Implementation)
**Conservative approach** (recommended):
{{REFACTOR_APPROACH}}

**Changes to make**:
{{SPECIFIC_CHANGES}}

### VERIFY PHASE
```bash
make clean && make
echo "BUILD: $?"
test -f build/bin/pawel-yaml && echo "Binary OK"
wc -l {{TARGET_FILES}}
stat -c%s build/bin/pawel-yaml
git diff {{TARGET_FILES}} | head -150
```

---

## SPECIFIC REFACTORING HINTS

{{CYCLE_SPECIFIC_HINTS}}

---

## BUILDING & TESTING

### Build Command
```bash
make clean && make
```

### Success Criteria  
```
✅ Compilation succeeds (exit code 0)
✅ No new warnings beyond existing
✅ Binary exists: build/bin/pawel-yaml
✅ Lines reduced: {{LINES_TOTAL}} → ~{{TARGET_LINES}} (target reduction)
```

---

## SUCCESS METRICS

✅ Build passes: `make clean && make`  
✅ Binary built: `test -f build/bin/pawel-yaml`  
✅ Lines reduced: {{LINES_TOTAL}} → {{TARGET_LINES}} (net {{TARGET_REDUCTION}})  
✅ Diff reviewed: Consolidation/deletion, no logic changes  
✅ Committed: `git log -1 --oneline`

---

**Ready?** Execute refactoring now!
