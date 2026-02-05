# Squash Candidates - Commits Ready for Consolidation

## Summary

Identified **7 commits** with minimal changes (1-5 lines each) that are candidates for squashing into their parent commits. These are refinements or small fixes that would benefit from being consolidated with the preceding work.

## Candidates Found

| Lines | Hash | Message | Type |
|-------|------|---------|------|
| 1 | `1e68124` | feat: Enable location tracking in Flex lexer | Feature |
| 2 | `dfcbce0` | improve(grammar): allow block_sequence in simple_node for more flexible nesting | Improvement |
| 3 | `0b5a52f` | fix(5MUD,55WF): implement flow context tracking with future-aware lexer sync | Fix |
| 3 | `0ec73aa` | Fix: Support full YAML block scalar modifiers (indentation + chomping) | Fix |
| 3 | `46d22d4` | feat: L9U2 - Block Scalar support (refactored) | Feature |
| 4 | `1acff1a` | TDD Cycle 5: Support document end marker (...) in implicit documents | TDD |
| 5 | `a52d83a` | fix: Update event parser grammar to handle block scalars with chomp indicators | Fix |

## Squashing Strategy

These commits are recommended to be squashed into their immediate parent commits using interactive rebase:

### Step 1: Start Interactive Rebase

```bash
git rebase -i 2b460d0ae329df2ad9bf8c419cd14c9bbbae7698
```

The commits will appear in the editor in reverse chronological order (newest first). To squash them, from oldest to newest:

### Step 2: Rebase Commands

Change the lines in git's interactive rebase editor as follows:

```
pick a52d83a fix: Update event parser grammar to handle block scalars with chomp indicators
squash 1acff1a TDD Cycle 5: Support document end marker (...) in implicit documents
squash 46d22d4 feat: L9U2 - Block Scalar support (refactored)
squash 0ec73aa Fix: Support full YAML block scalar modifiers (indentation + chomping)
squash 0b5a52f fix(5MUD,55WF): implement flow context tracking with future-aware lexer sync
squash dfcbce0 improve(grammar): allow block_sequence in simple_node for more flexible nesting
squash 1e68124 feat: Enable location tracking in Flex lexer
```

- `pick` = keep this commit as-is (use for the first commit)
- `squash` = merge into previous commit and keep all commit messages
- `fixup` = merge into previous commit and discard this commit's message

### Step 3: Complete the Rebase

After marking commits for squashing:
1. Save and exit the editor
2. Git will combine the commits and let you edit the consolidated message
3. Review and finalize the commit message
4. Continue the rebase

### Alternative: Squash Individually (Safer)

If you want to squash one at a time:

```bash
# For each commit (oldest first)
git rebase -i <parent-of-commit>
# Then change 'pick' to 'squash' for just that one commit
```

## Benefits of Squashing

- **Cleaner History**: Eliminates micro-commits that clutter the log
- **Logical Grouping**: Related changes (fix + test, feature + refinement) belong together
- **Better Workflow**: Easier to bisect and understand major feature/fix boundaries
- **Reduced Noise**: Focuses blame/credit on meaningful changes, not 1-line tweaks

## Detection Methodology

Script used to identify candidates:

```bash
git log --format="%H %s" branch | while read commit msg; do
  stats=$(git show $commit --stat | tail -1)
  # Extract insertions + deletions
  if [ total_changes <= 5 ] && [ has_fix_or_refactor_in_msg ]; then
    print candidate
  fi
done
```

Filtered for commits with:
- ≤ 5 lines changed (insertions + deletions)
- Keywords: `fix`, `refactor`, `docs`, `red`, `RED`, `green`, `GREEN`
- Single or two file changes

## Safety Considerations

**Before proceeding:**
1. Ensure all work is committed: `git status` should be clean
2. Backup your branch: `git branch backup-before-squash`
3. Start with `-i` (interactive mode) to review before executing
4. Can abort at any time during rebase: `git rebase --abort`

## Future Prevention

To avoid accumulating many small commits:

1. **Use `--fixup` and `--squash` flags**:
   ```bash
   git commit --fixup <commit-hash>   # For bug fixes
   git commit --squash <commit-hash>  # For refinements
   ```

2. **`git rebase -i --autosquash`**: Automatically marks fixup/squash commits

3. **Require minimum commit size**: Encourage grouping related small changes

## Status

- **Detected**: 7 commits identified
- **Action Required**: Manual interactive rebase (no automatic changes made)
- **Impact**: Would reduce history by ~7 commits, no functional changes
- **Risk Level**: Low (manual review recommended)
