# Copilot Instructions for Oh My Zsh Custom Plugins

## Project Overview
This is a collection of custom Oh My Zsh plugins that extend zsh functionality with bulk git operations and custom aliases. The main plugin is `git-checkout-all`, which provides comprehensive multi-repository git management.

## Plugin Structure
Each plugin follows Oh My Zsh conventions:
- Plugin directory: `<plugin-name>/`
- Main file: `<plugin-name>/<plugin-name>.plugin.zsh`
- Loaded automatically when added to `.zshrc` plugins array

### Modular Architecture (git-checkout-all)
The git-checkout-all plugin is organized into separate modules for maintainability:
```
git-checkout-all/
├── git-checkout-all.plugin.zsh  # Main entry point, sources libraries and defines aliases
├── lib/
    ├── utils.zsh                # Shared utility functions
    ├── bulk-operations.zsh      # Functions operating on all repos
    └── single-operations.zsh    # Functions operating on single repo
```

**Module loading pattern:**
```zsh
PLUGIN_DIR="${0:A:h}"
source "${PLUGIN_DIR}/lib/utils.zsh"
source "${PLUGIN_DIR}/lib/bulk-operations.zsh"
source "${PLUGIN_DIR}/lib/single-operations.zsh"
```

## Core Architecture: git-checkout-all Plugin

### Design Pattern: Utility-First Functions
All main commands follow this structure:
1. **Private utility functions** prefixed with `_` in `lib/utils.zsh` (e.g., `_get_git_repositories`, `_validate_repository`)
2. **Public command functions** in `lib/bulk-operations.zsh` or `lib/single-operations.zsh`
3. **Short aliases** defined in main plugin file (e.g., `ggcoa`, `ggfa`)

Example utility pattern in `lib/utils.zsh`:
```zsh
_validate_repository() {
  local repo_name="$1"
  local base_path="${2:-$(pwd)}"
  # Validation logic
  return 0 or 1
}
```

### File Organization

#### lib/utils.zsh
Contains all shared utility functions:
- Repository validation (`_validate_repository`, `_get_git_repositories`)
- Git operations (`_branch_exists_local`, `_branch_exists_remote`, `_remote_exists`)
- Branch management (`_can_fast_forward`, `_pull_branch_updates`)
- Processing (`_process_repository_fetch`)
- Output formatting (`_print_header`, `_print_summary`)

#### lib/bulk-operations.zsh
Functions operating on all repositories in current directory:
- `git-checkout-all` - Checkout/create branch in all repos
- `git-fetch-all` - Fetch all repos with optional prune/pull
- `git-match-origin-all` - Sync branches between remotes
- `git-list-branches-all` - List all branches across repos
- `git-status-all` - Show status of all repos

#### lib/single-operations.zsh
Functions operating on a single specified repository:
- `git-fetch-one` - Fetch single repo
- `git-status-one` - Detailed status for single repo
- `git-list-branches-one` - List branches in single repo

### Multi-Repository Operations
All bulk operations iterate over subdirectories in `$(pwd)`:
```zsh
for dir in "$base_path"/*/; do
  if [ -d "$dir/.git" ]; then
    # Operate on each git repo
  fi
done
```

### Key Commands & Their Logic

#### git-checkout-all (alias: ggcoa)
- Supports `-b` flag for creating new branches (like `git checkout -b`)
- Auto-detects if branch exists locally, remotely, or nowhere
- Three checkout modes:
  1. Local branch exists → checkout directly
  2. Remote branch exists → create from remote (`git checkout -b <branch> origin/<branch>`)
  3. Create new branch → use `-b` flag

#### git-fetch-all (alias: ggfa)
- Flags: `--prune`, `--pull`
- `--pull` specifically targets: `develop-pjp`, `develop`, `staging`, `master`
- Uses `_pull_branch_updates()` with fast-forward-only merges for safety
- Returns to original branch after updates

#### git-match-origin-all (alias: ggmoa)
- Syncs branches between two remotes (e.g., upstream → origin)
- Always attempts fast-forward first
- Prompts for confirmation on non-fast-forward merges
- Uses temporary branch `temp_sync_<branch>` for safety

### Output Conventions
- Header separator: 45 dashes (`─────────────────────────────────────────────────`)
- Emoji prefixes: 📁 (repo), ✅ (success), ❌ (error), ⚠️ (warning), 🔄 (sync), 🌿 (branch)
- Summary format: "📊 Summary: X/Y repositories <operation>"

### Testing Workflow
When adding new commands:
1. Determine if it's bulk or single-repo operation
2. Add utility functions to `lib/utils.zsh` if reusable
3. Add main function to appropriate file (`lib/bulk-operations.zsh` or `lib/single-operations.zsh`)
4. Add parameter validation at function start
5. Use subshells `(cd "$dir" && {...})` to avoid affecting current directory
6. Define alias in main plugin file
7. Update help function with new command

## Code Style Guidelines

### Error Handling
```zsh
if [ -z "$branch_name" ]; then
  echo "Usage: git-checkout-all [-b] <branch-name>"
  return 1
fi
```

### Boolean Flags
```zsh
local use_prune=false
if [ "$use_prune" = true ]; then
  # Do something
fi
```

### Array Handling
```zsh
local target_branches=("develop-pjp" "develop" "staging" "master")
for branch in "${target_branches[@]}"; do
  # Process each branch
done
```

### Subshell Pattern for Repository Operations
```zsh
(cd "$target_dir" && {
  # Git operations here
  # Exit codes and echoes propagate to parent
})
```

## vt745 Plugin Patterns
Contains workflow aliases for common git operations:
- Branch merging workflows: `gmtodevelop`, `gmtostaging`, `gmtomaster`
  - Pattern: Save current branch → checkout target → pull → merge with `--no-ff --no-edit`
- Git tag operations: `gtprune` (delete all local tags), `gtfetch` (fetch remote tags)
- Laravel IDE helper: `artcc` (combined artisan ide-helper commands)

## Adding New Plugins
1. Create directory: `mkdir <plugin-name>`
2. Create file: `<plugin-name>/<plugin-name>.plugin.zsh`
3. For larger plugins, create `lib/` subdirectory with modular files
4. Follow naming conventions:
   - Functions: `<plugin-scope>-<action>` or `<plugin-scope>-<action>-<target>`
   - Aliases: Short 2-5 char combinations (e.g., `ggcoa`, `ggfa`)
5. Include help function: `<plugin-name>-help`

## Extending git-checkout-all Plugin
1. Add utility functions to `lib/utils.zsh` if they're reusable
2. Add bulk operations to `lib/bulk-operations.zsh`
3. Add single-repo operations to `lib/single-operations.zsh`
4. Define aliases in main plugin file
5. Keep functions focused and single-purpose to avoid duplication

## Important Notes
- All bulk operations expect subdirectories containing git repositories
- Single-repo operations validate repo existence with `_validate_repository`
- Fast-forward-only merges ensure safety when pulling/syncing
- Original branch is always restored after operations
- Modular design eliminates code duplication across operations
- License: MIT (Copyright 2025 Natan S)
