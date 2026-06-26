---
description: Repository overview and project purpose.
alwaysApply: true
---

# Project Context — Oh My Zsh Custom Plugins

## Repository Purpose

This is a collection of **production-grade Oh My Zsh plugins** for advanced Git operations, multi-repository management, and workflow automation. The plugins extend zsh shell capabilities with powerful bulk git commands and smart repository utilities.

**What this repo is:**
- A curated set of zsh plugins following Oh My Zsh conventions
- Source-of-truth for shell extensions deployed to `~/.oh-my-zsh/custom/plugins/`
- Modular, testable, and documented utilities for Git workflow automation

**What this repo is NOT:**
- A standalone tool; requires Oh My Zsh installation
- A package manager or dependency manager
- A replacement for git — plugins augment git with convenience operations

## Repository Structure

| Directory | Role |
|-----------|------|
| `git-checkout-all/` | Primary plugin: bulk git operations and branch management |
| `vt745/` | Secondary plugin: video encoding, subtitle processing, photo utilities |
| `example/` | Template plugin demonstrating Oh My Zsh plugin structure |
| `.github/` | GitHub-specific configuration (deprecated Copilot bridge, migrate to `.agents/`) |

## Plugin Design Pattern

All plugins follow this architecture:

```
<plugin-name>/
├── <plugin-name>.plugin.zsh      # Main entry point, sources lib/ and defines aliases
├── lib/                           # Optional: modular function library (bulk/single-ops)
│   ├── utils.zsh                 # Shared utility functions
│   ├── bulk-operations.zsh       # Functions operating on all repos/items
│   └── single-operations.zsh     # Functions operating on single repo/item
└── test-*.zsh                     # Optional: inline test files (sourced manually)
```

**Module loading convention:**
```zsh
PLUGIN_DIR="${0:A:h}"
source "${PLUGIN_DIR}/lib/utils.zsh"
source "${PLUGIN_DIR}/lib/bulk-operations.zsh"
source "${PLUGIN_DIR}/lib/single-operations.zsh"
```

## Core Plugins

### git-checkout-all
- **Purpose:** Multi-repository Git branch management and checkout
- **Key features:** bulk checkout, auto-create tracking branches, safe merges, gone-branch cleanup
- **Architecture:** utility-first (private `_` prefixed funcs, public command funcs, short aliases)
- **Aliases:** `ggcoa` (checkout), `ggfa` (fetch), `ggmoa` (match-origin), `ggba` (branches), `ggsa` (status)

### vt745
- **Purpose:** Video processing, subtitle translation/renaming, photo tools
- **Scripts:** `exiftool.sh`, `rename_video.sh`, `rename_subtitles.sh`, `translate_subtitle.sh/py`, `split_log.py`
- **Dependencies:** exiftool, ffmpeg, subtitle processors (non-zsh; shell wrappers)

## Code Style Conventions

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
  # Safe comparison
fi
```

### Subshell Pattern (Don't Pollute CWD)
```zsh
(cd "$target_dir" && {
  git status
  # Exit code and echoes propagate; CWD restored when subshell exits
})
```

### Output & Emoji Conventions
- Header separator: 45 dashes (`──────────────────────────────────────────────`)
- Repo indicator: 📁; Success: ✅; Error: ❌; Warning: ⚠️; Sync: 🔄; Branch: 🌿
- Summary: `📊 Summary: X/Y repositories <operation>`

## Development Workflow

### Adding a New Command
1. Determine if it's **bulk** (all repos) or **single** (one repo) operation
2. Add utility functions to `lib/utils.zsh` (private, prefixed with `_`)
3. Add main function to `lib/bulk-operations.zsh` or `lib/single-operations.zsh`
4. Add parameter validation at function start
5. Use subshells `(cd "$dir" && {...})` to avoid affecting current directory
6. Define short alias in main plugin file
7. Update help function

### Testing
- Inline test files: `test-config.zsh`, `test-remote-pc-update.zsh` (run manually)
- Test actual git operations in a temporary monorepo setup
- Validate fast-forward-only merge behavior

## Documentation

- **Installation:** [README.md](../../README.md) — setup and plugin enablement
- **Architecture:** [architecture.md](./architecture.md) — detailed component breakdown
- **Code patterns:** This file + inline comments in .plugin.zsh and lib/ files
