# GitHub Copilot — AI Agent Instructions

> **Primary instructions:** see [`AGENTS.md`](../AGENTS.md) for the full AI agent guide.
>
> This file is the Copilot bridge. All agents share the same source of truth in `AGENTS.md`.

**Version:** 1.0.0 — **Updated:** 2026-06-26

---

## Quick Reference

| Resource | Path |
|----------|------|
| **Primary instructions** | [`AGENTS.md`](../AGENTS.md) |
| Rules | `.agents/rules/` |
| Skills | `.agents/skills/` (symlinked at `.github/skills/`, `.cursor/skills/`) |
| Prompts (shared) | `.agents/prompts/` |
| Full plugin README | [`README.md`](../README.md) |

---

## Repository Purpose (Brief)

Oh My Zsh custom plugins for **bulk Git operations** and **multi-repository management**. Primary plugin (`git-checkout-all`) provides intelligent branch checkout, safe merging, and comprehensive status reporting across all repos in a directory.

All code is **shell-only** (zsh/bash + git) — no external language dependencies.

---

## Critical Conventions

### Modular Plugin Structure
- Private functions in `lib/utils.zsh` (prefixed with `_`)
- Public command functions in `lib/bulk-operations.zsh` or `lib/single-operations.zsh`
- Short aliases in main plugin file (e.g., `ggcoa`, `ggfa`)

### Safe Multi-Repository Operations
- All merge operations are **fast-forward-only** (`--ff-only`)
- Use subshells `(cd "$dir" && ...)` to isolate working directory
- Always restore original branch after multi-branch operations

### Output Formatting
- Emoji prefixes: 📁 (repo), ✅ (success), ❌ (error), 🔄 (sync), 🌿 (branch)
- Header separator: 45 dashes (`─────────────────────────────────────────────────`)
- Summary format: `📊 Summary: X/Y repositories <operation>`

### Branch Auto-Detection
1. Check if branch exists locally → checkout directly
2. Check if branch exists remotely → create tracking branch
3. If `-b` flag provided → create new branch
4. Otherwise → fail with reason

---

## Common Commands

| Command | Alias | What It Does |
|---------|-------|--------------|
| `git-checkout-all main` | `ggcoa main` | Checkout `main` in all repos (auto-create from remote if needed) |
| `git-checkout-all -b feature/x` | `ggcoa -b feature/x` | Create new `feature/x` in all repos |
| `git-fetch-all` | `ggfa` | Fetch all repos |
| `git-fetch-all --pull` | `ggfa --pull` | Fetch + pull `develop`, `staging`, `master` (FF-only) |
| `git-match-origin-all` | `ggmoa` | Sync branches upstream → origin |
| `git-list-branches-all` | `ggba` | List all branches in each repo |
| `git-status-all` | `ggsa` | Show git status for each repo |

---

## Architecture Overview

See [`.agents/rules/architecture.md`](../.agents/rules/architecture.md) for detailed data flows and components.

**High level:**
```
Request (e.g., ggcoa develop)
  → Iterate over all repos in $(pwd)
  → Validate repository, detect branch existence
  → Smart checkout (local, then remote, then create)
  → Output per-repo status + summary
```

---

## Where to Look First

1. **Understanding the repo:** [`.agents/rules/project-context.md`](../.agents/rules/project-context.md)
2. **How git-checkout-all works:** [`.agents/rules/architecture.md`](../.agents/rules/architecture.md)
3. **Full plugin reference:** [`README.md`](../README.md)
4. **Source code:** [`git-checkout-all/git-checkout-all.plugin.zsh`](../git-checkout-all/git-checkout-all.plugin.zsh) + [`git-checkout-all/lib/`](../git-checkout-all/lib/)
