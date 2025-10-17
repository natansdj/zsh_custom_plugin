# Git Checkout All Plugin
# Author: natansdj
# Description: Comprehensive git operations for multiple repositories in current directory

# Utility Functions
# =================

# Get all git repositories in current directory
_get_git_repositories() {
  local base_path="${1:-$(pwd)}"
  local repos=()
  
  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      repos+=($(basename "$dir"))
    fi
  done
  
  printf '%s\n' "${repos[@]}"
}

# Check if repository exists and is a git repo
_validate_repository() {
  local repo_name="$1"
  local base_path="${2:-$(pwd)}"
  local target_dir="$base_path/$repo_name"

  if [ ! -d "$target_dir" ]; then
    echo "❌ Directory '$repo_name' not found in $base_path"
    return 1
  fi

  if [ ! -d "$target_dir/.git" ]; then
    echo "❌ '$repo_name' is not a git repository"
    return 1
  fi

  return 0
}

# Check if remote exists in repository
_remote_exists() {
  local remote_name="$1"
  git remote | grep -q "^${remote_name}$"
}

# Check if branch exists locally
_branch_exists_local() {
  local branch_name="$1"
  git rev-parse --verify "$branch_name" >/dev/null 2>&1
}

# Check if branch exists on remote
_branch_exists_remote() {
  local remote_name="$1"
  local branch_name="$2"
  git ls-remote --heads "$remote_name" "$branch_name" 2>/dev/null | grep -q "$branch_name"
}

# Check if current branch can be fast-forwarded to target
_can_fast_forward() {
  local target_ref="$1"
  local merge_base=$(git merge-base HEAD "$target_ref" 2>/dev/null)
  local head_commit=$(git rev-parse HEAD 2>/dev/null)
  
  [ "$merge_base" = "$head_commit" ]
}

# Print section header
_print_header() {
  echo "$1"
  echo "─────────────────────────────────────────────────"
}

# Print summary
_print_summary() {
  local success_count="$1"
  local total_count="$2"
  local operation="$3"
  
  echo "─────────────────────────────────────────────────"
  echo "📊 Summary: $success_count/$total_count repositories $operation"
  
  if [ $total_count -eq 0 ]; then
    echo "⚠️  No git repositories found in $(pwd)"
  fi
}

# Main function to checkout branch in all repositories
git-checkout-all() {
  local create_branch=false
  local branch_name=""
  local base_path="$(pwd)"
  local success_count=0
  local total_repos=0

  # Parse options and arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -b)
        create_branch=true
        shift
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: git-checkout-all [-b] <branch-name>"
        echo "  -b    Create new branch locally (like git checkout -b)"
        echo "Example: git-checkout-all main"
        echo "Example: git-checkout-all -b feature/new-feature"
        return 1
        ;;
      *)
        if [ -z "$branch_name" ]; then
          branch_name="$1"
        else
          echo "Error: Multiple branch names provided"
          echo "Usage: git-checkout-all [-b] <branch-name>"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate branch name is provided
  if [ -z "$branch_name" ]; then
    echo "Usage: git-checkout-all [-b] <branch-name>"
    echo "  -b    Create new branch locally (like git checkout -b)"
    echo "Example: git-checkout-all main"
    echo "Example: git-checkout-all -b feature/new-feature"
    return 1
  fi

  _print_header "🔍 Searching for git repositories in $(pwd)..."
  if [ "$create_branch" = true ]; then
    echo "🆕 Creating and checking out new branch: $branch_name"
  else
    echo "🌿 Attempting to checkout branch: $branch_name"
  fi

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      total_repos=$((total_repos + 1))

      echo -n "📁 $repo_name: "
      (cd "$dir" && {
        if [ "$create_branch" = true ]; then
          # Creating new branch mode
          if _branch_exists_local "$branch_name"; then
            echo "⚠️  Branch already exists locally"
          else
            if git checkout -b "$branch_name" >/dev/null 2>&1; then
              echo "✅ Created and checked out"
              success_count=$((success_count + 1))
            else
              echo "❌ Failed to create branch"
            fi
          fi
        else
          # Regular checkout mode (existing behavior)
          # Check if branch exists locally
          if _branch_exists_local "$branch_name"; then
            if git checkout "$branch_name" >/dev/null 2>&1; then
              echo "✅ Success"
              success_count=$((success_count + 1))
            else
              echo "❌ Failed to checkout"
            fi
          # Check if branch exists on remote
          elif _branch_exists_remote "origin" "$branch_name"; then
            if git checkout -b "$branch_name" "origin/$branch_name" >/dev/null 2>&1; then
              echo "✅ Success (created from remote)"
              success_count=$((success_count + 1))
            else
              echo "❌ Failed to create from remote"
            fi
          else
            echo "⚠️  Branch not found"
          fi
        fi
      })
    fi
  done

  if [ "$create_branch" = true ]; then
    _print_summary "$success_count" "$total_repos" "branches created"
  else
    _print_summary "$success_count" "$total_repos" "updated"
  fi
}

# Alias for shorter command
alias ggcoa='git-checkout-all'

# Function to fetch all repositories
git-fetch-all() {
  local base_path="$(pwd)"
  local use_prune=false
  local use_pull=false
  local success_count=0
  local total_repos=0
  local pull_count=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prune)
        use_prune=true
        shift
        ;;
      --pull)
        use_pull=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        echo "Usage: git-fetch-all [--prune] [--pull]"
        return 1
        ;;
    esac
  done

  local fetch_options=""
  local operation_desc="Fetching"
  
  if [ "$use_prune" = true ]; then
    fetch_options="--prune"
    operation_desc="$operation_desc with prune"
  fi
  
  if [ "$use_pull" = true ]; then
    operation_desc="$operation_desc and pulling"
  fi

  _print_header "🔄 $operation_desc all repositories in $(pwd)..."

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      total_repos=$((total_repos + 1))

      echo -n "📁 $repo_name: "
      (cd "$dir" && {
        # First, fetch
        if git fetch $fetch_options >/dev/null 2>&1; then
          local fetch_success=true
          echo -n "✅ Fetched"
          success_count=$((success_count + 1))
          
          # If --pull is specified, try to update local branches
          if [ "$use_pull" = true ] && [ "$fetch_success" = true ]; then
            local current_branch=$(git branch --show-current 2>/dev/null)
            local updated=false
            
            if [ -n "$current_branch" ]; then
              # Check if there are updates available
              local upstream="origin/$current_branch"
              if git rev-parse --verify "$upstream" >/dev/null 2>&1; then
                local local_commit=$(git rev-parse HEAD 2>/dev/null)
                local remote_commit=$(git rev-parse "$upstream" 2>/dev/null)
                
                if [ "$local_commit" != "$remote_commit" ]; then
                  # There are updates, try to pull
                  if _can_fast_forward "$upstream"; then
                    if git merge --ff-only "$upstream" >/dev/null 2>&1; then
                      echo " + 🔄 Pulled (fast-forward)"
                      updated=true
                      pull_count=$((pull_count + 1))
                    else
                      echo " ⚠️ Pull failed"
                    fi
                  else
                    echo " ⚠️ Cannot fast-forward, manual merge needed"
                  fi
                else
                  echo " (up to date)"
                fi
              else
                echo " (no upstream)"
              fi
            else
              echo " (detached HEAD)"
            fi
            
            if [ "$updated" = false ] && [ "$use_pull" = true ]; then
              echo ""
            fi
          else
            echo ""
          fi
        else
          echo "❌ Failed"
        fi
      })
    fi
  done

  if [ "$use_pull" = true ]; then
    _print_summary "$success_count" "$total_repos" "fetched, $pull_count pulled"
  else
    _print_summary "$success_count" "$total_repos" "fetched"
  fi
}

# Function to match origins across repositories
git-match-origin-all() {
  if [ $# -lt 3 ]; then
    echo "Usage: git-match-origin-all <origin_1> <origin_2> <branch> [repository]"
    echo "Example: git-match-origin-all upstream origin main"
    echo "Example: git-match-origin-all upstream origin main my-repo"
    return 1
  fi

  local origin_1="$1"
  local origin_2="$2"
  local branch_name="$3"
  local target_repo="$4"
  local base_path="$(pwd)"
  local success_count=0
  local total_repos=0
  local repositories=()

  # Determine which repositories to process
  if [ -n "$target_repo" ]; then
    if ! _validate_repository "$target_repo" "$base_path"; then
      return 1
    fi
    repositories=("$target_repo")
  else
    while IFS= read -r repo; do
      repositories+=("$repo")
    done < <(_get_git_repositories "$base_path")
  fi

  if [ ${#repositories[@]} -eq 0 ]; then
    echo "⚠️  No git repositories found"
    return 1
  fi

  _print_header "🔄 Matching $origin_1 -> $origin_2 for branch '$branch_name'..."

  for repo_name in "${repositories[@]}"; do
    total_repos=$((total_repos + 1))
    local target_dir="$base_path/$repo_name"

    echo -n "📁 $repo_name: "
    (cd "$target_dir" && {
      # Check if both remotes exist
      if ! _remote_exists "$origin_1"; then
        echo "❌ Remote '$origin_1' not found"
        return
      fi

      if ! _remote_exists "$origin_2"; then
        echo "❌ Remote '$origin_2' not found"
        return
      fi

      # Fetch from both remotes
      if ! git fetch "$origin_1" >/dev/null 2>&1; then
        echo "❌ Failed to fetch from $origin_1"
        return
      fi

      if ! git fetch "$origin_2" >/dev/null 2>&1; then
        echo "❌ Failed to fetch from $origin_2"
        return
      fi

      local origin_1_ref="$origin_1/$branch_name"
      local origin_2_ref="$origin_2/$branch_name"

      # Check if branch exists on origin_1
      if ! git rev-parse --verify "$origin_1_ref" >/dev/null 2>&1; then
        echo "⚠️  Branch '$branch_name' not found on $origin_1"
        return
      fi

      # Check if branch exists on origin_2
      if ! git rev-parse --verify "$origin_2_ref" >/dev/null 2>&1; then
        echo "⚠️  Branch '$branch_name' not found on $origin_2"
        return
      fi

      # Check if they are already in sync
      local origin_1_commit=$(git rev-parse "$origin_1_ref" 2>/dev/null)
      local origin_2_commit=$(git rev-parse "$origin_2_ref" 2>/dev/null)

      if [ "$origin_1_commit" = "$origin_2_commit" ]; then
        echo "✅ Already in sync"
        success_count=$((success_count + 1))
        return
      fi

      # Check if we can fast-forward
      local current_branch=$(git branch --show-current 2>/dev/null)
      local original_branch="$current_branch"

      # Checkout the target branch from origin_2
      if ! git checkout -B "temp_sync_$branch_name" "$origin_2_ref" >/dev/null 2>&1; then
        echo "❌ Failed to checkout temp branch"
        return
      fi

      # Try to merge with fast-forward
      if _can_fast_forward "$origin_1_ref"; then
        if git merge --ff-only "$origin_1_ref" >/dev/null 2>&1; then
          # Push back to origin_2
          if git push "$origin_2" "temp_sync_$branch_name:$branch_name" >/dev/null 2>&1; then
            echo "✅ Synced (fast-forward)"
            success_count=$((success_count + 1))
          else
            echo "❌ Failed to push to $origin_2"
          fi
        else
          echo "❌ Fast-forward merge failed"
        fi
      else
        # Non-fast-forward merge needed, ask for confirmation
        echo -n "⚠️  Non-fast-forward needed. Continue? [y/N]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          if git merge --no-ff "$origin_1_ref" -m "Merge $origin_1/$branch_name into $origin_2/$branch_name" >/dev/null 2>&1; then
            if git push "$origin_2" "temp_sync_$branch_name:$branch_name" >/dev/null 2>&1; then
              echo "✅ Synced (merge)"
              success_count=$((success_count + 1))
            else
              echo "❌ Failed to push to $origin_2"
            fi
          else
            echo "❌ Merge failed"
          fi
        else
          echo "⏭️  Skipped"
        fi
      fi

      # Cleanup: return to original branch if it existed
      if [ -n "$original_branch" ]; then
        git checkout "$original_branch" >/dev/null 2>&1
      else
        git checkout HEAD~0 >/dev/null 2>&1  # Return to detached state
      fi

      # Delete temp branch
      git branch -D "temp_sync_$branch_name" >/dev/null 2>&1
    })
  done

  _print_summary "$success_count" "$total_repos" "synchronized"
}

# Alias for fetch all
alias ggfa='git-fetch-all'

# Alias for match origin all
alias ggmoa='git-match-origin-all'

# Function to list all branches across repositories
git-list-branches-all() {
  local base_path="$(pwd)"

  echo "🌿 Listing branches across all repositories in $(pwd):"
  echo "─────────────────────────────────────────────────"

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      echo "📁 $repo_name:"
      (cd "$dir" && {
        local current_branch=$(git branch --show-current 2>/dev/null || echo "")
        if [ -n "$current_branch" ]; then
          # Use a safer approach to highlight current branch
          git branch -a 2>/dev/null | while IFS= read -r line; do
            # Remove leading/trailing whitespace and check if it's the current branch
            clean_line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ "$line" == *"* "* ]]; then
              # This is the current branch line
              echo "  ✅ ${clean_line#* }"
            else
              echo "  $line"
            fi
          done
        else
          git branch -a 2>/dev/null | sed 's/^/  /' 2>/dev/null || echo "  (no branches found)"
        fi
      })
      echo
    fi
  done
}

# Alias for branch listing
alias glba='git-list-branches-all'

# Function to show current branch status in all repositories
git-status-all() {
  local base_path="$(pwd)"

  echo "📊 Current branch status across all repositories:"
  echo "─────────────────────────────────────────────────"

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      echo -n "📁 $repo_name: "
      (cd "$dir" && {
        local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
        local git_status=$(git status --porcelain 2>/dev/null || echo "")
        if [ -n "$git_status" ]; then
          echo "🌿 $current_branch (📝 uncommitted changes)"
        else
          echo "🌿 $current_branch (✨ clean)"
        fi
      })
    fi
  done
}

# Alias for status check
alias gsa='git-status-all'

# Function to show current branch status for a single repository
git-status-one() {
  if [ -z "$1" ]; then
    echo "Usage: git-status-one <repo-name>"
    echo "Example: git-status-one my-project"
    return 1
  fi

  local repo_name="$1"
  local base_path="$(pwd)"

  if ! _validate_repository "$repo_name" "$base_path"; then
    return 1
  fi

  local target_dir="$base_path/$repo_name"
  
  _print_header "📊 Status for repository: $repo_name"

  (cd "$target_dir" && {
    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local git_status=$(git status --porcelain 2>/dev/null || echo "")
    local ahead_behind=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "")

    echo "📁 Repository: $repo_name"
    echo "🌿 Current branch: $current_branch"

    if [ -n "$ahead_behind" ]; then
      local ahead=$(echo "$ahead_behind" | cut -f1)
      local behind=$(echo "$ahead_behind" | cut -f2)
      if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        echo "🔄 Remote sync: $ahead ahead, $behind behind"
      else
        echo "🔄 Remote sync: up to date"
      fi
    else
      echo "🔄 Remote sync: no upstream set"
    fi

    if [ -n "$git_status" ]; then
      echo "📝 Working directory: uncommitted changes"
      echo ""
      echo "Changed files:"
      git status --porcelain 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
      done
    else
      echo "✨ Working directory: clean"
    fi
  })
}

# Alias for single status check
alias gso='git-status-one'

# Function to list all branches in a single repository
git-list-branches-one() {
  if [ -z "$1" ]; then
    echo "Usage: git-list-branches-one <repo-name>"
    echo "Example: git-list-branches-one my-project"
    return 1
  fi

  local repo_name="$1"
  local base_path="$(pwd)"

  if ! _validate_repository "$repo_name" "$base_path"; then
    return 1
  fi

  local target_dir="$base_path/$repo_name"

  _print_header "🌿 Branches in repository: $repo_name"

  (cd "$target_dir" && {
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")

    echo "Local branches:"
    if [ -n "$current_branch" ]; then
      git branch 2>/dev/null | while IFS= read -r line; do
        clean_line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [[ "$line" == *"* "* ]]; then
          echo "  ✅ ${clean_line#* } (current)"
        else
          echo "  🌿 $clean_line"
        fi
      done
    else
      git branch 2>/dev/null | sed 's/^/  🌿 /' 2>/dev/null || echo "  (no local branches found)"
    fi

    echo ""
    echo "Remote branches:"
    git branch -r 2>/dev/null | sed 's/^/  🔗 /' 2>/dev/null || echo "  (no remote branches found)"
  })
}

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
  echo "  git-match-origin-all <o1> <o2> <br> [repo] - Sync branch from origin1 to origin2 (alias: ggmoa)"
  echo "  git-list-branches-all                 - List all branches in all repos (alias: glba)"
  echo "  git-status-all                        - Show current branch status (alias: gsa)"
  echo ""
  echo "SINGLE REPO OPERATIONS:"
  echo "  git-status-one <repo>                 - Show detailed status for one repo (alias: gso)"
  echo "  git-list-branches-one <repo>          - List all branches in one repo (alias: glbo)"
  echo ""
  echo "  git-checkout-all-help                 - Show this help message"
  echo ""
  echo "Examples:"
  echo "BULK:"
  echo "  ggcoa main                             # Checkout main branch in all repos"
  echo "  ggcoa -b feature/new-feature           # Create new branch locally in all repos"
  echo "  ggfa                                   # Fetch all repos"
  echo "  ggfa --prune                           # Fetch all repos with prune"
  echo "  ggfa --pull                            # Fetch and pull updates in all repos"
  echo "  ggfa --prune --pull                    # Fetch with prune and pull updates"
  echo "  ggmoa upstream origin main             # Sync main branch from upstream to origin"
  echo "  ggmoa upstream origin dev my-repo      # Sync dev branch only in my-repo"
  echo "  glba                                   # List all branches in all repos"
  echo "  gsa                                    # Show current status of all repos"
  echo ""
  echo "SINGLE:"
  echo "  gso my-project                         # Show detailed status for 'my-project'"
  echo "  glbo my-project                        # List all branches in 'my-project'"
  echo ""
  echo "ADVANCED:"
  echo "  git-match-origin-all:"
  echo "    - Fetches from both remotes"
  echo "    - Fast-forwards when possible"
  echo "    - Asks confirmation for non-fast-forward merges"
  echo "    - Works on all repos or specific repo if provided"
  echo ""
  echo "Note: All commands work on subdirectories of the current working directory"
}
