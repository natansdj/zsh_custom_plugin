---
description: Detailed architecture and data flow for bulk git operations.
applyTo: '**/git-checkout-all/**'
---

# Architecture — git-checkout-all Plugin

## System Overview

The git-checkout-all plugin provides **bulk Git operations across multiple repositories** with safe merging, branch auto-detection, and comprehensive status reporting.

### Request Flow: Bulk Branch Checkout

```
User invokes: ggcoa develop
    ↓
git-checkout-all(branch_name="develop", create_flag=false)
    ↓
Iterate over all directories in $(pwd)
    ├─ _validate_repository("$(basename $dir)") — check .git/ exists
    ├─ _branch_exists_local("develop") — check local branch
    ├─ Case A: exists locally → git checkout develop
    ├─ Case B: exists remotely → git checkout -b develop origin/develop
    └─ Case C: does not exist → skip with warning
    ↓
_print_summary "checkout" "X/Y successful"
```

### Request Flow: Fetch with Pull-Down

```
User invokes: ggfa --pull
    ↓
git-fetch-all(use_pull=true)
    ↓
For each repository:
    ├─ git fetch
    ├─ For each target branch (develop-pjp, develop, staging, master):
    │   ├─ _can_fast_forward("origin/develop") — check merge-base
    │   ├─ Yes → _pull_branch_updates("develop")
    │   │   (git checkout develop && git merge --ff-only origin/develop)
    │   └─ Restore original branch
    └─ Output per-repo status
    ↓
_print_summary "fetch" "X/Y successful"
```

## Component Architecture

### 1. **utils.zsh** — Shared Utilities

**Repository Validation**
- `_get_git_repositories(base_path)` — find all .git/ subdirectories
- `_validate_repository(repo_name, base_path)` — check if directory contains .git

**Branch Detection**
- `_branch_exists_local(branch_name)` — query local branch
- `_branch_exists_remote(branch_name, remote="origin")` — query remote tracking branch
- `_remote_exists(remote_name)` — check if remote is configured

**Merge Safety**
- `_can_fast_forward(upstream_ref)` — check if merge-base matches upstream
- `_pull_branch_updates(branch_name)` — safe checkout + fast-forward-only merge

**Processing**
- `_process_repository_fetch(repo_dir, flags)` — execute fetch operations per repo

**Output**
- `_print_header(repo_name, operation)` — formatted header with 45-dash separator
- `_print_summary(operation, count_success, count_total)` — emoji-formatted summary

### 2. **bulk-operations.zsh** — Multi-Repository Commands

| Function | Behavior |
|----------|----------|
| `git-checkout-all(branch, create_flag)` | Checkout or create branch in all repos |
| `git-fetch-all(prune, pull)` | Fetch all; optionally pull target branches |
| `git-match-origin-all(source_remote, target_remote)` | Sync branches upstream→origin |
| `git-list-branches-all()` | List all branches across all repos |
| `git-status-all()` | Show git status for each repo |

**Safety patterns:**
- All merge operations are **fast-forward-only** (`--ff-only`)
- Original branch is **restored** after operations
- Subshells `(cd "$dir" && ...)` isolate CWD changes

### 3. **single-operations.zsh** — Single-Repository Commands

| Function | Behavior |
|----------|----------|
| `git-fetch-one(repo_name)` | Fetch a single repo |
| `git-status-one(repo_name)` | Detailed status for a single repo |
| `git-list-branches-one(repo_name)` | List branches in a single repo |

**Distinguisher:** Always validate target repository before operating.

## Dependency Graph

```
main plugin file
├─ sources lib/utils.zsh
├─ sources lib/bulk-operations.zsh
│   └─ calls _* functions from utils.zsh
├─ sources lib/single-operations.zsh
│   └─ calls _* functions from utils.zsh
└─ defines short aliases (ggcoa, ggfa, etc.)
```

## State and Outputs

### Input State
- Current working directory contains multiple git repositories as direct subdirectories
- Each subdirectory has `.git/` present (validated by `_validate_repository`)

### Output Format
- **Per-repository:**
  - 📁 `<repo_name>` — operation header
  - ✅ / ❌ `<operation result>` — outcome
- **Summary:**
  - 📊 `Summary: X/Y repositories <operation>`

### Critical Behaviors

1. **Branch auto-detection:** Try local first, then remote, then fail
2. **Fast-forward-only merges:** Never performs real merges; rejects non-FF situations
3. **Branch restoration:** Always returns to original branch after multi-branch operations
4. **Idempotency:** Re-running same command produces same result (within same repo state)

## Integration Points

- **No external services** — pure local git operations
- **No configuration files** — all behavior via command flags and git state
- **Shell-only:** no dependencies on Python, Ruby, Node, or external binaries (pure bash/zsh + git)

## Testing Considerations

1. **Multi-repo setup:** Create temp git repos as siblings to test bulk operations
2. **Branch conditions:** Test local-only, remote-only, and missing branch scenarios
3. **Merge safety:** Verify fast-forward-only logic prevents accidental merges
4. **CWD isolation:** Confirm subshells don't affect user's directory after command exits
5. **Empty directories:** Verify handling of non-git directories (skipped silently)
