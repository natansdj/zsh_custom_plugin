# Oh My Zsh Custom Plugins Collection

A comprehensive collection of custom Oh My Zsh plugins for advanced Git operations, multi-repository management, and workflow automation.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Plugins](#plugins)
  - [git-checkout-all](#git-checkout-all-plugin)
  - [vt745](#vt745-plugin)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This plugin collection provides powerful tools for managing multiple Git repositories simultaneously, streamlining common Git workflows, and automating repetitive tasks. Whether you're working in a monorepo environment or managing multiple related projects, these plugins will significantly boost your productivity.

### Key Highlights

- **Bulk Git Operations**: Perform git operations across all repositories in a directory
- **Single Repository Operations**: Targeted operations on specific repositories
- **Smart Branch Management**: Auto-detection of local/remote branches with intelligent fallback
- **Safe Merge Operations**: Fast-forward-only merges with confirmation prompts for complex cases
- **Comprehensive Status Reporting**: Rich, emoji-enhanced output with detailed summaries
- **Modular Architecture**: Clean, maintainable code structure with separated concerns

---

## Installation

### 1. Clone this repository into your Oh My Zsh custom plugins directory:

```bash
cd ~/.oh-my-zsh/custom/plugins
git clone <your-repo-url> .
```

### 2. Enable the plugins in your `~/.zshrc`:

```bash
plugins=(
  # ... other plugins
  git-checkout-all
  vt745
)
```

### 3. Restart your terminal or reload zsh:

```bash
source ~/.zshrc
```

---

## Plugins

## git-checkout-all Plugin

The primary plugin providing comprehensive multi-repository Git management capabilities with support for bulk and single-repository operations.

### Architecture

The plugin follows a modular design pattern:

```
git-checkout-all/
├── git-checkout-all.plugin.zsh  # Main entry point & alias definitions
└── lib/
    ├── utils.zsh                # Shared utility functions
    ├── bulk-operations.zsh      # Operations on all repos
    └── single-operations.zsh    # Operations on single repo
```

### Core Features

#### 1. **Bulk Operations** (All Repositories)

Operations that affect all Git repositories in the current directory.

##### `git-checkout-all` (alias: `ggcoa`)
**Purpose**: Checkout or create branches across all repositories.

**Capabilities**:
- Auto-detects if branch exists locally, remotely, or nowhere
- Creates tracking branches from remote when needed
- Supports creating new branches with `-b` flag
- Provides clear status for each repository

**Usage**:
```bash
# Checkout existing branch
ggcoa main
ggcoa feature/new-api

# Create new branch locally in all repos (like git checkout -b)
ggcoa -b feature/new-feature
git-checkout-all -b hotfix/critical-bug
```

**Smart Branch Detection**:
1. **Local branch exists** → Checkout directly
2. **Remote branch exists** → Create tracking branch (`git checkout -b <branch> origin/<branch>`)
3. **Branch doesn't exist** → Show warning (unless `-b` flag used)

**Output Example**:
```
🔍 Searching for git repositories in /projects...
🌿 Attempting to checkout branch: develop
─────────────────────────────────────────────────
📁 project-1: ✅ Success
📁 project-2: ✅ Success (created from remote)
📁 project-3: ⚠️  Branch not found
─────────────────────────────────────────────────
📊 Summary: 2/3 repositories updated
```

##### `git-fetch-all` (alias: `ggfa`)
**Purpose**: Fetch updates from remotes across all repositories with optional prune and pull.

**Capabilities**:
- Fetches all remotes for every repository
- Optional `--prune` to remove stale remote-tracking branches
- Optional `--pull` to update specific branches (develop-pjp, develop, staging, master)
- Smart pull with fast-forward-only merges
- Returns to original branch after updates
- Detailed reporting of pulled branches

**Usage**:
```bash
# Basic fetch
ggfa
git-fetch-all

# Fetch with prune
ggfa --prune

# Fetch and pull specific branches
ggfa --pull

# Fetch with prune and pull
ggfa --prune --pull
```

**Pull Behavior**:
- **Target branches**: Configurable via environment variable or config file (default: `develop-pjp`, `develop`, `staging`, `master`)
- **Configuration**: See [Configuration → Target Branches](#target-branches-configuration) section
- **Safety**: Uses `--ff-only` (fast-forward-only) merges
- **Branch preservation**: Returns to original branch after updates
- **Smart detection**: Only updates branches that exist both locally and remotely
- **Change detection**: Only pulls if remote has new commits

**Output Example**:
```
🔄 Fetching and pulling all repositories in /projects...
─────────────────────────────────────────────────
📁 project-1: ✅ Fetched + 🔄 Pulled 2 branch(es): develop staging
📁 project-2: ✅ Fetched (no updates for develop-pjp/develop/staging/master)
📁 project-3: ✅ Fetched + 🔄 Pulled 1 branch(es): develop
─────────────────────────────────────────────────
📊 Summary: 3/3 repositories fetched, 3 pulled
```

##### `git-match-origin-all` (alias: `ggmoa`)
**Purpose**: Synchronize branches between two remotes (e.g., upstream → origin).

**Capabilities**:
- Syncs specified branch from one remote to another
- Works across all repositories or specific repository
- Fetches from both remotes before syncing
- Attempts fast-forward merge first
- Prompts for confirmation on non-fast-forward merges
- Uses temporary branches for safety
- Validates remote existence before operation

**Usage**:
```bash
# Sync branch across all repositories
ggmoa upstream origin main
git-match-origin-all upstream origin develop

# Sync branch in specific repository only
ggmoa upstream origin feature/new-api my-project
```

**Sync Process**:
1. Validates both remotes exist
2. Fetches from both remotes
3. Checks if branches are already in sync
4. **Fast-forward possible**: Automatically syncs
5. **Non-fast-forward required**: Prompts for confirmation
6. Uses temporary branch `temp_sync_<branch>` for safety
7. Returns to original branch after sync
8. Cleans up temporary branch

**Output Example**:
```
🔄 Matching upstream -> origin for branch 'main'...
─────────────────────────────────────────────────
📁 project-1: ✅ Synced (fast-forward)
📁 project-2: ✅ Already in sync
📁 project-3: ⚠️  Non-fast-forward needed. Continue? [y/N]: y
📁 project-3: ✅ Synced (merge)
─────────────────────────────────────────────────
📊 Summary: 3/3 repositories synchronized
```

##### `git-list-branches-all` (alias: `glba`)
**Purpose**: List all local and remote branches across all repositories.

**Capabilities**:
- Shows all local branches with current branch highlighted
- Shows all remote branches
- Clear visual distinction between current and other branches
- Organized by repository

**Usage**:
```bash
glba
git-list-branches-all
```

**Output Example**:
```
🌿 Listing branches across all repositories in /projects:
─────────────────────────────────────────────────
📁 project-1:
  ✅ main
  feature/auth
  remotes/origin/main
  remotes/origin/develop
  remotes/origin/feature/auth

📁 project-2:
  develop
  ✅ feature/api
  remotes/origin/main
  remotes/origin/develop
```

##### `git-status-all` (alias: `gsa`)
**Purpose**: Show current branch and working directory status for all repositories.

**Capabilities**:
- Displays current branch for each repository
- Indicates clean vs. uncommitted changes
- Compact, one-line-per-repo format
- Quick overview of entire project state

**Usage**:
```bash
gsa
git-status-all
```

**Output Example**:
```
📊 Current branch status across all repositories:
─────────────────────────────────────────────────
📁 project-1: 🌿 main (✨ clean)
📁 project-2: 🌿 develop (📝 uncommitted changes)
📁 project-3: 🌿 feature/new-api (✨ clean)
```

#### 2. **Single Repository Operations**

Targeted operations for specific repositories with detailed output.

##### `git-fetch-one` (alias: `ggfo`)
**Purpose**: Fetch a specific repository with optional prune and pull.

**Capabilities**:
- All features of `git-fetch-all` but for a single repository
- Supports `--prune` and `--pull` flags
- More detailed output than bulk operations
- Validates repository exists before operation

**Usage**:
```bash
# Basic fetch
ggfo my-project
git-fetch-one my-project

# Fetch with prune
ggfo --prune my-project

# Fetch and pull
ggfo --pull my-project

# Fetch with prune and pull
ggfo --prune --pull my-project
```

**Output Example**:
```
🔄 Fetching and pulling repository: my-project
─────────────────────────────────────────────────
📁 my-project: ✅ Fetched + 🔄 Pulled 2 branch(es): develop staging

✅ Repository fetched successfully, 2 branch(es) pulled
```

##### `git-status-one` (alias: `gso`)
**Purpose**: Show detailed status for a specific repository.

**Capabilities**:
- Displays current branch
- Shows remote sync status (ahead/behind commits)
- Indicates upstream tracking status
- Lists all changed files
- Shows working directory state

**Usage**:
```bash
gso my-project
git-status-one my-project
```

**Output Example**:
```
📊 Status for repository: my-project
─────────────────────────────────────────────────
📁 Repository: my-project
🌿 Current branch: feature/new-api
🔄 Remote sync: 2 ahead, 0 behind
📝 Working directory: uncommitted changes

Changed files:
  M src/api/routes.js
  M package.json
  ?? src/api/new-endpoint.js
```

##### `git-list-branches-one` (alias: `glbo`)
**Purpose**: List all branches in a specific repository.

**Capabilities**:
- Shows all local branches with current branch highlighted
- Shows all remote branches
- Separated sections for local and remote branches
- Clear visual indicators

**Usage**:
```bash
glbo my-project
git-list-branches-one my-project
```

**Output Example**:
```
🌿 Branches in repository: my-project
─────────────────────────────────────────────────
Local branches:
  🌿 main
  ✅ feature/new-api (current)
  🌿 develop

Remote branches:
  🔗 origin/main
  🔗 origin/develop
  🔗 origin/feature/new-api
  🔗 origin/staging
```

### Utility Functions (Internal)

These functions are used internally by the plugin but are available for advanced usage:

#### Repository Management
- `_get_git_repositories()` - Get all git repos in directory
- `_validate_repository()` - Validate repo exists and is git repo

#### Git Operations
- `_remote_exists()` - Check if remote exists
- `_branch_exists_local()` - Check if branch exists locally
- `_branch_exists_remote()` - Check if branch exists on remote
- `_can_fast_forward()` - Check if fast-forward merge is possible

#### Branch Management
- `_pull_branch_updates()` - Pull updates for specific branches
- `_process_repository_fetch()` - Process fetch/pull for single repo

#### Output Formatting
- `_print_header()` - Print section header with separator
- `_print_summary()` - Print operation summary

### Configuration

#### General Settings

The plugin works with these assumptions:
- **Working directory**: Operations target subdirectories of `$(pwd)`
- **Remote naming**: Primary remote is `origin` by default
- **Merge strategy**: Fast-forward-only for safety

#### Target Branches Configuration

The `--pull` flag updates specific branches automatically. You can configure which branches to target using three methods (in priority order):

**1. Environment Variable (Highest Priority)**

Set the `GIT_CHECKOUT_ALL_TARGET_BRANCHES` environment variable in your `~/.zshrc`:

```bash
# Comma-separated list
export GIT_CHECKOUT_ALL_TARGET_BRANCHES="develop,staging,main"

# Alternative with spaces (will be trimmed)
export GIT_CHECKOUT_ALL_TARGET_BRANCHES="develop, staging, main, production"
```

**2. Configuration File**

Create `~/.git-checkout-all.conf` with your target branches:

```bash
# One branch per line (recommended)
develop
staging
main
production

# Or comma-separated
# develop,staging,main,production

# Comments and empty lines are ignored
```

**3. Default Configuration**

If no configuration is found, these default branches are used:
- `develop-pjp`
- `develop`
- `staging`
- `master`

**Example Configuration File**

A sample configuration file is provided at:
```
git-checkout-all/.git-checkout-all.conf.example
```

Copy it to your home directory and customize:
```bash
cp ~/.oh-my-zsh/custom/plugins/git-checkout-all/.git-checkout-all.conf.example ~/.git-checkout-all.conf
# Edit the file to add/remove branches
```

**Verification**

To verify your configuration is loaded, use the help command which shows the configured branches:
```bash
git-checkout-all-help
```

### Error Handling

The plugin provides clear error messages:
- Missing repositories
- Invalid git repositories
- Missing remotes
- Non-existent branches
- Failed git operations
- Merge conflicts

### Help System

Access comprehensive help with:
```bash
git-checkout-all-help
```

### Additional Documentation

- **[QUICK_START.md](git-checkout-all/QUICK_START.md)** - Quick reference for target branches configuration
- **[CONFIGURATION.md](git-checkout-all/CONFIGURATION.md)** - Complete configuration guide with examples and troubleshooting
- **[.git-checkout-all.conf.example](git-checkout-all/.git-checkout-all.conf.example)** - Sample configuration file

---

## vt745 Plugin

A collection of workflow-specific Git aliases for common development patterns.

### Features

#### Branch Merging Workflows

Quick merge current branch into target branches with standard merge commit:

```bash
# Merge current branch to develop
gmtodevelop
# Equivalent to:
# TMPBRANCH=$(git branch --show-current) && 
# gco develop && 
# ggpull && 
# gm --no-ff --no-edit $TMPBRANCH

# Merge current branch to staging
gmtostaging

# Merge current branch to master
gmtomaster

# Merge current branch to development
gmtodevelopment
```

**Workflow**:
1. Saves current branch name
2. Checks out target branch
3. Pulls latest changes
4. Merges with `--no-ff --no-edit` (creates merge commit without editor)

#### Git Tag Management

```bash
# Delete all local tags
gtprune
# Equivalent to: git tag -l | xargs git tag -d

# Fetch all tags from remote
gtfetch
# Equivalent to: git fetch --tags

# List all tags with annotations
gtlist
# Equivalent to: git tag -l -n99
```

#### Branch Cleanup

```bash
# Clean merged remote branches
gitcleanmerged
# Deletes remote branches that are merged into master
# (excludes master, develop, staging)

# Clean merged local branches
gitcleanmergedlocal
# Deletes local branches that are merged into master
# (excludes master, develop, staging)
```

#### Docker Shortcuts

```bash
doa         # docker attach --sig-proxy=false
dcupd       # docker-compose up -d
dcc         # docker-compose create
dcsa        # docker-compose start
dcso        # docker-compose stop
```

#### Laravel IDE Helper

```bash
artcc       # Run all Laravel IDE helper commands
# Equivalent to:
# php artisan ide-helper:eloquent && 
# php artisan ide-helper:generate && 
# php artisan ide-helper:meta && 
# php artisan ide-helper:models -N
```

#### Quick Git Aliases

```bash
gcd         # git checkout dev
```

---

## Architecture

### Design Principles

1. **Modular Structure**: Separated concerns (utils, bulk ops, single ops)
2. **Code Reusability**: Shared utility functions eliminate duplication
3. **Single Source of Truth**: Configuration and logic centralized
4. **Safety First**: Fast-forward-only merges, confirmation prompts
5. **Rich Feedback**: Emoji-enhanced output with detailed summaries
6. **Error Handling**: Comprehensive validation and clear error messages

### Code Organization

```
plugins/
├── git-checkout-all/           # Main multi-repo management plugin
│   ├── git-checkout-all.plugin.zsh
│   └── lib/
│       ├── utils.zsh           # Shared utilities (13 functions)
│       ├── bulk-operations.zsh # Bulk operations (5 commands)
│       └── single-operations.zsh # Single repo operations (3 commands)
├── vt745/                      # Workflow aliases
│   └── vt745.plugin.zsh
├── example/                    # Example plugin template
│   └── example.plugin.zsh
├── LICENSE                     # MIT License
└── README.md                   # This file
```

### Extension Pattern

To add new functionality:

1. **Add utility function** to `lib/utils.zsh` if reusable
2. **Add operation** to `lib/bulk-operations.zsh` or `lib/single-operations.zsh`
3. **Define alias** in main plugin file
4. **Update help** in `git-checkout-all-help()` function
5. **Test thoroughly** with multiple scenarios

### Naming Conventions

- **Functions**: `<scope>-<action>-<target>` (e.g., `git-checkout-all`)
- **Private utilities**: `_<name>` prefix (e.g., `_validate_repository`)
- **Aliases**: Short 2-5 character combinations (e.g., `ggcoa`, `ggfa`)
- **Variables**: Snake_case for local vars, UPPERCASE for constants

---

## Use Cases

### Scenario 1: Monorepo with Multiple Services

```bash
# Switch all services to develop branch
cd ~/projects/monorepo
ggcoa develop

# Fetch all and update main branches
ggfa --pull

# Check status across all services
gsa
```

### Scenario 2: Create New Feature Branch

```bash
# Create feature branch in all repos
cd ~/projects
ggcoa -b feature/new-authentication

# Later, merge to develop
# (switch to each repo individually and use vt745 plugin)
cd project-1 && gmtodevelop
cd ../project-2 && gmtodevelop
```

### Scenario 3: Sync Fork with Upstream

```bash
# Sync main branch from upstream to origin across all repos
cd ~/projects/forks
ggmoa upstream origin main

# Sync develop branch
ggmoa upstream origin develop
```

### Scenario 4: Daily Maintenance

```bash
# Morning routine: update all repos
cd ~/projects
ggfa --prune --pull
gsa

# Check specific project details
gso my-critical-project
glbo my-critical-project
```

### Scenario 5: Release Workflow

```bash
# Ensure all repos on staging
ggcoa staging
ggfa --pull

# Verify status
gsa

# Merge to master (per repo)
cd project-1 && gmtomaster
cd ../project-2 && gmtomaster

# Create release tags
gtfetch  # Fetch existing tags
# Create new tags per repo
```

---

## Troubleshooting

### Common Issues

**Issue**: Command not found
```bash
# Solution: Ensure plugin is enabled in ~/.zshrc and reload
source ~/.zshrc
```

**Issue**: Operations affecting wrong directories
```bash
# Solution: Always run commands from parent directory of repos
cd /path/to/parent
ggcoa main
```

**Issue**: Fast-forward merge fails
```bash
# Solution: Use git-match-origin-all which prompts for non-ff merges
ggmoa upstream origin branch-name
```

**Issue**: Branch not found in some repos
```bash
# Solution: Check which repos are missing the branch
glba | grep -A 5 "repo-name"
```

---

## Performance

### Benchmarks

Typical performance on modern hardware:

- **10 repositories**: ~2-3 seconds for fetch
- **50 repositories**: ~10-15 seconds for fetch with pull
- **100 repositories**: ~25-30 seconds for full sync

### Optimization Tips

1. Use `--pull` only when needed (adds overhead)
2. Run `ggfa --prune` periodically to clean stale branches
3. Use single-repo operations (`ggfo`, `gso`) for targeted updates
4. Consider running operations in parallel for very large sets

---

## Best Practices

1. **Always check status first**: Use `gsa` before bulk operations
2. **Use `-b` flag explicitly**: When creating new branches to avoid confusion
3. **Verify before sync**: Check `glba` before `ggmoa` operations
4. **Pull regularly**: Use `ggfa --pull` daily to stay updated
5. **Clean up branches**: Regularly prune merged branches
6. **Test in single repo**: Use single-repo operations first for testing

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Code Style**: Follow existing naming conventions and structure
2. **Modularity**: Add reusable functions to `lib/utils.zsh`
3. **Testing**: Test with multiple repositories and edge cases
4. **Documentation**: Update this README with new features
5. **Commit Messages**: Use conventional commits format

### Adding New Features

See [Architecture → Extension Pattern](#extension-pattern) for details.

---

## License

MIT License

Copyright (c) 2025 Natan S

See [LICENSE](LICENSE) file for full details.

---

## Changelog

### Version 1.1.0 (November 2025)

**git-checkout-all plugin**:
- ✅ **NEW**: Dynamic target branches configuration
  - Configure via environment variable `GIT_CHECKOUT_ALL_TARGET_BRANCHES`
  - Configure via config file `~/.git-checkout-all.conf`
  - Defaults maintained for backward compatibility
- ✅ Enhanced documentation with configuration examples

### Version 1.0.0

**git-checkout-all plugin**:
- ✅ Bulk branch checkout with auto-detection
- ✅ Create branches with `-b` flag
- ✅ Fetch with optional prune and pull
- ✅ Branch synchronization between remotes
- ✅ Comprehensive status and branch listing
- ✅ Single repository operations
- ✅ Rich emoji-enhanced output
- ✅ Modular architecture

**vt745 plugin**:
- ✅ Branch merge workflow aliases
- ✅ Git tag management
- ✅ Branch cleanup utilities
- ✅ Docker shortcuts
- ✅ Laravel IDE helper integration

---

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing issues and discussions
- Review this README for common solutions

---

## Credits

**Author**: Natan S (natansdj)  
**Year**: 2025  
**Plugin Collection**: Oh My Zsh Custom Plugins

Special thanks to the Oh My Zsh community for the excellent framework.

---

**Happy Git-ing! 🚀**
