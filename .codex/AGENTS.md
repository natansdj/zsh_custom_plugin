# Codex — AI Agent Instructions

> **Primary source of truth:** [`../AGENTS.md`](../AGENTS.md)
>
> This bridge file delegates to the unified SOT.

**Version:** 1.0.0 — **Updated:** 2026-06-26

---

## Quick Reference

| Resource | Path |
|----------|------|
| **Primary instructions** | [`AGENTS.md`](../AGENTS.md) |
| Rules | `.agents/rules/` (symlinked at `.codex/rules/`) |
| Skills | `.codex/skills/` (symlink → `.agents/skills/`) |
| Prompts | `.agents/prompts/` |

---

## Getting Started

1. **Read full context:** Open [`../AGENTS.md`](../AGENTS.md) for complete AI agent instructions
2. **Repository overview:** [`../.agents/rules/project-context.md`](../.agents/rules/project-context.md)
3. **Architecture deep-dive:** [`../.agents/rules/architecture.md`](../.agents/rules/architecture.md)

---

## What This Repository Is

**Oh My Zsh custom plugins collection** for advanced Git operations, multi-repository management, and workflow automation. All code is **shell-only** (pure zsh/bash + git).

### Main Plugin: `git-checkout-all`
- Bulk Git operations across multiple repositories
- Intelligent branch detection and checkout
- Safe merging (fast-forward-only)
- Comprehensive status reporting
- Modular, testable design

### Secondary Plugin: `vt745`
- Video encoding, subtitle processing, photo utilities

---

## Critical Code Patterns

### Pattern 1: Private Utilities → Public Commands → Aliases
```zsh
# lib/utils.zsh
_validate_repository() { ... }
_branch_exists_local() { ... }

# lib/bulk-operations.zsh
git-checkout-all() { 
  for dir in ...; do
    _validate_repository ...
    _branch_exists_local ...
  done
}

# main plugin file
alias ggcoa='git-checkout-all'
```

### Pattern 2: Fast-Forward-Only Merges + CWD Isolation
```zsh
(cd "$target_dir" && {
  git merge --ff-only origin/branch
  # Never fails with merge conflicts; subshell restores CWD
})
```

### Pattern 3: Branch Auto-Detection
```zsh
if _branch_exists_local "$branch"; then
  git checkout "$branch"
elif _branch_exists_remote "$branch"; then
  git checkout -b "$branch" "origin/$branch"
else
  echo "❌ Branch not found"
  return 1
fi
```

---

## Common Development Tasks

| Task | Where to Look |
|------|----------------|
| Add a new git command | `git-checkout-all/lib/bulk-operations.zsh` (or `single-operations.zsh`) |
| Add a utility function | `git-checkout-all/lib/utils.zsh` |
| Update command aliases | `git-checkout-all/git-checkout-all.plugin.zsh` |
| Understand architecture | [`../.agents/rules/architecture.md`](../.agents/rules/architecture.md) |
| See all conventions | [`../AGENTS.md`](../AGENTS.md) — Critical Conventions section |

---

All agents read from the unified SOT in `AGENTS.md` to ensure consistency.
