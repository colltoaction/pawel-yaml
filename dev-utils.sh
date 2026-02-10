#!/bin/bash
# Unified development utilities - consolidates 9 separate scripts
# Usage: ./dev-utils.sh [check|status|debug|resolve|continue|show|head|final]

set -e
cd /home/widip/titi-org/pawel-yaml

# --- Check Commands ---
cmd_check() {
    case "${2:-status}" in
        status)
            echo "=== GIT STATUS ==="
            git status
            echo ""
            echo "=== STAGED CHANGES ==="
            git diff --cached
            echo ""
            echo "=== UNSTAGED CHANGES ==="
            git diff | head -50
            ;;
        conflict)
            echo "=== REBASE STATUS ==="
            git status
            echo ""
            echo "=== CONFLICT DIFF ==="
            git diff | head -100
            ;;
        changes)
            echo "=== GIT STATUS ==="
            git status
            echo ""
            echo "=== STAGED CHANGES ==="
            git diff --cached
            echo ""
            echo "=== UNSTAGED CHANGES ==="
            git diff src/yaml_parser.c 2>/dev/null | head -50 || git diff | head -50
            ;;
        *)
            echo "Usage: $0 check [status|conflict|changes]"
            ;;
    esac
}

# --- Status Commands ---
cmd_status() {
    echo "=== CURRENT BRANCH ==="
    git branch -v
    echo ""
    echo "=== LAST 3 COMMITS ==="
    git log --oneline -3
    echo ""
    echo "=== STATUS ==="
    git status
}

# --- Debug Commands ---
cmd_debug() {
    case "${2:-rebase}" in
        rebase)
            echo "=== Debug: Rebase state ==="
            if [ -d .git/rebase-merge ]; then
                echo "✓ Active rebase-merge"
                echo "Step: $(cat .git/rebase-merge/msgnum)/$(cat .git/rebase-merge/end)"
            else
                echo "✗ No active rebase"
            fi
            echo ""
            echo "=== Current HEAD ==="
            git log --oneline -1
            echo ""
            echo "Total commits: $(git log --oneline | wc -l)"
            ;;
        head)
            GIT_PAGER=cat git log --oneline -1
            ;;
        *)
            echo "Usage: $0 debug [rebase|head]"
            ;;
    esac
}

# --- Rebase Commands ---
cmd_resolve() {
    echo "=== STAGING RESOLVED FILES ==="
    git add -u
    echo "✓ Changes staged"
    echo ""
    echo "=== CONTINUING REBASE ==="
    GIT_EDITOR=cat git rebase --continue
    echo ""
    echo "=== STATUS ==="
    git status --short
}

cmd_continue() {
    echo "=== REBASE CONTINUE ==="
    GIT_EDITOR=cat git rebase --continue
    echo "✓ Rebase continued"
}

# --- Analysis Commands ---
cmd_show() {
    COMMIT="${2:-49c712cc0722cf45624b9b4cb0ed6ae4216a3e8c}"
    echo "=== COMMIT ANALYSIS: $COMMIT ==="
    echo ""
    echo "Message:"
    git log --format="%s" -1 "$COMMIT" 2>/dev/null || echo "Commit not found"
    echo ""
    echo "Files changed:"
    git show --name-status "$COMMIT" 2>/dev/null | grep -E "^[A-Z]" | head -20
    echo ""
    echo "Stats:"
    git show --stat "$COMMIT" 2>/dev/null | tail -10
}

cmd_final() {
    echo "=== FINAL BUILD CHECK ==="
    if [ -f build/bin/pawel-yaml ]; then
        echo "✓ Binary: $(stat -c '%s' build/bin/pawel-yaml) bytes"
    else
        echo "✗ Binary not found"
    fi
    echo ""
    echo "=== CURRENT BRANCH ==="
    git branch | grep "^\*"
    echo ""
    echo "=== LAST 3 COMMITS ==="
    git log --oneline -3
}

# --- Main ---
case "${1:-status}" in
    check) cmd_check "$@" ;;
    status) cmd_status ;;
    debug) cmd_debug "$@" ;;
    resolve) cmd_resolve ;;
    continue) cmd_continue ;;
    show) cmd_show "$@" ;;
    final) cmd_final ;;
    help)
        cat << 'EOF'
Development Utilities - Consolidated tooling

Commands:
  check [status|conflict|changes]  Check git status and changes
  status                           Show branch and commit status
  debug [rebase|head]              Debug rebase state or show HEAD
  resolve                          Stage files and continue rebase
  continue                         Continue rebase with default editor
  show [commit]                    Analyze commit (default: cycle9 target)
  final                            Final build and status check
  help                             Show this help

Examples:
  ./dev-utils.sh check conflict    # Check rebase conflicts
  ./dev-utils.sh debug rebase      # Debug rebase state
  ./dev-utils.sh resolve           # Resolve and continue rebase
  ./dev-utils.sh show 49c712cc     # Analyze specific commit
EOF
        ;;
    *)
        echo "Usage: $0 [check|status|debug|resolve|continue|show|final|help]"
        echo "Run '$0 help' for details"
        exit 1
        ;;
esac
