# Git Checkout All Plugin
# Author: natansdj
# Description: Comprehensive git operations for multiple repositories in current directory

# Get the directory where this plugin is located
PLUGIN_DIR="${0:A:h}"

# Source all library files
source "${PLUGIN_DIR}/lib/utils.zsh"
source "${PLUGIN_DIR}/lib/bulk-operations.zsh"
source "${PLUGIN_DIR}/lib/single-operations.zsh"

# Alias for shorter command
alias ggcoa='git-checkout-all'

# Alias for fetch all
alias ggfa='git-fetch-all'

# Alias for fetch one
alias ggfo='git-fetch-one'

# Alias for match origin all
alias ggmoa='git-match-origin-all'

# Alias for branch listing
alias glba='git-list-branches-all'

# Alias for tag listing all repos (renamed from glta)
alias ggtla='git-list-tag-all'

# Alias for tag listing single repo
alias ggtl='git-list-tag-one'

# Alias for tag creation
alias ggtc='git-tag-create'

# Alias for tag creation and push
alias ggtcp='git-tag-create-push'

# Alias for status check
alias gsa='git-status-all'

# Alias for single status check
alias gso='git-status-one'

# Alias for single branch listing
alias glbo='git-list-branches-one'

# Help function
git-checkout-all-help() {
  echo "Git Checkout All Plugin - Available Commands:"
  echo "─────────────────────────────────────────────────"
  echo "BULK OPERATIONS (all repos in current directory):"
  echo "  git-checkout-all [-b] <branch>        - Checkout branch in all repos (alias: ggcoa)"
  echo "                                          -b: Create new branch locally (like git checkout -b)"
  echo "  git-fetch-all [--prune] [--pull]      - Fetch all repos, optionally prune and pull (alias: ggfa)"
  echo "                                          --pull: Updates configured target branches (default: develop/staging/master)"
  echo "  git-match-origin-all <o1> <o2> <br> [repo] - Sync branch from origin1 to origin2 (alias: ggmoa)"
  echo "  git-list-branches-all                 - List all branches in all repos (alias: glba)"
  echo "  git-list-tag-all                      - List 5 latest tags in all repos (alias: ggtla)"
  echo "  git-status-all                        - Show current branch status (alias: gsa)"
  echo ""
  echo "SINGLE REPO OPERATIONS:"
  echo "  git-fetch-one [--prune] [--pull] <repo> - Fetch one repo, optionally prune and pull (alias: ggfo)"
  echo "  git-status-one <repo>                 - Show detailed status for one repo (alias: gso)"
  echo "  git-list-branches-one <repo>          - List all branches in one repo (alias: glbo)"
  echo "  git-list-tag-one <repo>               - List 5 latest tags in one repo (alias: ggtl)"
  echo ""
  echo "TAG CREATION:"
  echo "  git-tag-create <type> <repo> [--push] - Create new tag by incrementing from latest (alias: ggtc)"
  echo "                                          type: patch, minor, or major"
  echo "                                          --push: Push tag to remote after creation"
  echo "  git-tag-create-push <type> <repo>     - Create and push tag to remote (alias: ggtcp)"
  echo ""
  echo "  git-checkout-all-help                 - Show this help message"
  echo ""
  echo "Examples:"
  echo "BULK:"
  echo "  ggcoa main                             # Checkout main branch in all repos"
  echo "  ggcoa -b feature/new-feature           # Create new branch locally in all repos"
  echo "  ggfa                                   # Fetch all repos"
  echo "  ggfa --prune                           # Fetch all repos with prune"
  echo "  ggfa --pull                            # Fetch and pull updates for configured target branches"
  echo "  ggfa --prune --pull                    # Fetch with prune and pull specific branches"
  echo "  ggmoa upstream origin main             # Sync main branch from upstream to origin"
  echo "  ggmoa upstream origin dev my-repo      # Sync dev branch only in my-repo"
  echo "  glba                                   # List all branches in all repos"
  echo "  ggtla                                  # List 5 latest tags in all repos"
  echo "  gsa                                    # Show current status of all repos"
  echo ""
  echo "SINGLE:"
  echo "  ggfo my-project                        # Fetch one repo"
  echo "  ggfo --pull my-project                 # Fetch and pull configured target branches in one repo"
  echo "  ggfo --prune --pull my-project         # Fetch with prune and pull in one repo"
  echo "  gso my-project                         # Show detailed status for 'my-project'"
  echo "  glbo my-project                        # List all branches in 'my-project'"
  echo "  ggtl my-project                        # List 5 latest tags in 'my-project'"
  echo ""
  echo "TAG CREATION:"
  echo "  ggtc patch my-repo                     # Create patch tag (v1.0.1 -> v1.0.2)"
  echo "  ggtc minor my-repo                     # Create minor tag (v1.0.1 -> v1.1.0)"
  echo "  ggtc major my-repo                     # Create major tag (v1.0.1 -> v2.0.0)"
  echo "  ggtc patch my-repo --push              # Create patch tag and push to remote"
  echo "  ggtcp patch my-repo                    # Create patch tag and push (shortcut)"
  echo ""
  echo "ADVANCED:"
  echo "  git-fetch-all --pull:"
  echo "    - Updates configured target branches (default: develop, staging, master)"
  echo "    - Uses fast-forward merges only for safety"
  echo "    - Returns to original branch after updates"
  echo ""
  echo "  git-tag-create:"
  echo "    - Reads latest tag from repository"
  echo "    - Increments version based on type (patch/minor/major)"
  echo "    - Creates tag locally (use --push to push to remote)"
  echo "    - Tag format: vMAJOR.MINOR.PATCH (e.g., v1.0.1)"
  echo ""
  echo "CONFIGURATION:"
  echo "  Target branches for --pull can be configured in three ways (priority order):"
  echo "  1. Environment variable:"
  echo "       export GIT_CHECKOUT_ALL_TARGET_BRANCHES='develop,staging,main'"
  echo "  2. Config file (~/.git-checkout-all.conf):"
  echo "       develop"
  echo "       staging"
  echo "       main"
  echo "       # Or comma-separated: develop,staging,main"
  echo "  3. Default: develop, staging, master"
  echo ""
  echo "  git-match-origin-all:"
  echo "    - Fetches from both remotes"
  echo "    - Fast-forwards when possible"
  echo "    - Asks confirmation for non-fast-forward merges"
  echo "    - Works on all repos or specific repo if provided"
  echo ""
  echo "Note: All commands work on subdirectories of the current working directory"
}
