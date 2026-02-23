# Future-Aware Refactoring: Quick Reference Card

**Version**: 1.0 | **Date**: 2026-02-10

---

## 🎯 When to Use Which Cost Model

| Goal | Model | Formula | Select |
|------|-------|---------|--------|
| Find architectural pivots | **Positive** | `add + del` | High churn |
| Find complexity growth | **Negative** | `del - add` | Large negative |
| Find simplifications | **Negative** | `del - add` | Large positive |

---

## ⚡ Quick Start (5 Minutes)

```bash
# 1. Prerequisites
make clean && make && make setup

# 2. Generate cost model
mkdir -p build/tmp
git rev-list --reverse --topo-order HEAD | awk '
BEGIN { OFS="\t"; running=0; i=0; print "idx","sha","commit_total","running_total" }
{ sha=$0; cmd="git show --numstat --format=\"\" " sha; total=0
  while ((cmd | getline line) > 0) {
    n=split(line,a,"\t")
    if (n >= 2 && a[1] ~ /^[0-9]+$/ && a[2] ~ /^[0-9]+$/) total += a[1] + a[2]
  }
  close(cmd); i += 1; running += total; print i, sha, total, running
}' > build/tmp/running_totals.tsv

# 3. Run bisect (requires AWK script in build/tmp/)
awk -f build/tmp/heavy_path_bisect.awk build/tmp/running_totals.tsv \
    > build/tmp/divide_report.tsv 2> build/tmp/targets.log

# 4. View target
cat build/tmp/targets.log

# 5. Start rebase
TARGET_SHA=$(grep TARGET build/tmp/targets.log | awk '{print $4}')
# Create edit_rebase_todo.sh (see full guide)
GIT_SEQUENCE_EDITOR="$PWD/build/tmp/edit_rebase_todo.sh" git rebase -i --root
```

---

## 🔧 Key Commands

### Cost Model Generation

**Positive (Standard)**:
```bash
git rev-list --reverse --topo-order HEAD | awk '
BEGIN { OFS="\t"; running=0; i=0; print "idx","sha","commit_total","running_total" }
{ sha=$0; cmd="git show --numstat --format=\"\" " sha; total=0
  while ((cmd | getline line) > 0) {
    n=split(line,a,"\t")
    if (n >= 2 && a[1] ~ /^[0-9]+$/ && a[2] ~ /^[0-9]+$/) total += a[1] + a[2]
  }
  close(cmd); i += 1; running += total; print i, sha, total, running
}' > build/tmp/running_totals.tsv
```

**Negative (Code Growth)**:
```bash
# Same as above but: net_reduction = deletions - additions
additions=0; deletions=0
# ... in loop: additions += a[1]; deletions += a[2] ...
net_reduction = deletions - additions
running += net_reduction
```

### View Results

```bash
# Top commits by cost
tail -n +2 build/tmp/running_totals.tsv | sort -k3 -nr | head -10

# Selected target
cat build/tmp/targets.log | grep TARGET

# Bisect decisions
column -t -s $'\t' build/tmp/divide_report.tsv

# Inspect commit
git show --stat <sha>
```

---

## 🧪 TDD Stop Protocol

At each rebase edit stop:

```bash
# 1. SYNC
git checkout "$TIP_REF" -- .agent/tooling.sh

# 2. RED
./.agent/tooling.sh tdd:test <ID>  # Should fail or document expected behavior

# 3. GREEN
make clean && make
./.agent/tooling.sh tdd:test <ID>  # Should pass

# 4. REFACTOR
# Make improvements, continuously verify:
make clean && make && ./.agent/tooling.sh tdd:test <ID>

# 5. GATE
make clean && make  # Final build check

# 6. CONTINUE
git add <files> && git commit --amend  # If changes made
git rebase --continue
```

---

## 🚨 Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| AWK exit code 2 | Script missing | Recreate from guide |
| Rebase auto-completes | Idempotent (expected) | Document & proceed |
| Build fails at stop | Missing infra | `git checkout $TIP_REF -- Makefile` |
| Merge conflicts | History divergence | Inspect future: `git show $TIP_REF:<file>` |

---

## 📊 Algorithm Properties

- **Time**: O(log n) - 202 commits = 8 steps
- **Space**: O(n) - stores all commit data
- **Deterministic**: ✓ Same input = same output
- **Idempotent**: ✓ Safe to re-run

---

## 📁 File Locations

```
build/tmp/
├── running_totals.tsv          # Cost model data
├── divide_report.tsv           # Bisect decisions
├── targets.log                 # Selected commit
├── rebase_refs.env            # Saved references
├── heavy_path_bisect.awk      # Bisect algorithm
└── edit_rebase_todo.sh        # Rebase automation

.agent/
├── tooling.sh                 # TDD harness
└── PLAYBOOK/
    ├── FUTURE_AWARE_REFACTORING.prompt.md           # Original spec
    └── FUTURE_AWARE_REFACTORING_ENGINEERING_GUIDE.md # Full guide
```

---

## 🎓 Example Results

**Positive Model** (202 commits):
```
Target: Commit 66 (be6126c)
Cost: 4566 lines changed
Type: Major refactoring
Bisect: 8 steps
```

**Negative Model** (202 commits):
```
Target: Commit 112 (533722b)
Cost: -518 (518 added)
Type: Documentation growth
Top Reduction: Commit 79 (+5697)
Bisect: 8 steps
```

---

## 🔗 See Also

- Full engineering guide: `.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING_ENGINEERING_GUIDE.md`
- Original playbook: `.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING.prompt.md`
- Production reports: `build/tmp/REFACTOR_COMPLETION_*.md`

---

**Quick Help**: For detailed troubleshooting, algorithm theory, and advanced usage, see the full engineering guide.
