# Git Checkout All Plugin
# Author: Your Name
# Description: Comprehensive git operations for multiple repositories in current directory

# Main function to checkout branch in all repositories
git-checkout-all() {
  if [ -z "$1" ]; then
    echo "Usage: git-checkout-all <branch-name>"
    echo "Example: git-checkout-all main"
    return 1
  fi
  
  local branch_name="$1"
  local base_path="$(pwd)"
  local success_count=0
  local total_repos=0
  
  echo "🔍 Searching for git repositories in $(pwd)..."
  echo "🌿 Attempting to checkout branch: $branch_name"
  echo "─────────────────────────────────────────────────"
  
  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      total_repos=$((total_repos + 1))
      
      echo -n "📁 $repo_name: "
      (cd "$dir" && {
        # Check if branch exists locally
        if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
          if git checkout "$branch_name" >/dev/null 2>&1; then
            echo "✅ Success"
            success_count=$((success_count + 1))
          else
            echo "❌ Failed to checkout"
          fi
        # Check if branch exists on remote
        elif git ls-remote --heads origin "$branch_name" 2>/dev/null | grep -q "$branch_name"; then
          if git checkout -b "$branch_name" "origin/$branch_name" >/dev/null 2>&1; then
            echo "✅ Success (created from remote)"
            success_count=$((success_count + 1))
          else
            echo "❌ Failed to create from remote"
          fi
        else
          echo "⚠️  Branch not found"
        fi
      })
    fi
  done
  
  echo "─────────────────────────────────────────────────"
  echo "📊 Summary: $success_count/$total_repos repositories updated"
  
  if [ $total_repos -eq 0 ]; then
    echo "⚠️  No git repositories found in $(pwd)"
  fi
}

# Alias for shorter command
alias gcoa='git-checkout-all'

# Function to fetch all repositories
git-fetch-all() {
  local base_path="$(pwd)"
  local use_prune=false
  local success_count=0
  local total_repos=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prune)
        use_prune=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        echo "Usage: git-fetch-all [--prune]"
        return 1
        ;;
    esac
  done

  local fetch_options=""
  if [ "$use_prune" = true ]; then
    fetch_options="--prune"
    echo "🔄 Fetching with prune in all repositories in $(pwd)..."
  else
    echo "🔄 Fetching all repositories in $(pwd)..."
  fi

  echo "─────────────────────────────────────────────────"

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      local repo_name=$(basename "$dir")
      total_repos=$((total_repos + 1))

      echo -n "📁 $repo_name: "
      (cd "$dir" && {
        if git fetch $fetch_options >/dev/null 2>&1; then
          echo "✅ Success"
          success_count=$((success_count + 1))
        else
          echo "❌ Failed"
        fi
      })
    fi
  done

  echo "─────────────────────────────────────────────────"
  echo "📊 Summary: $success_count/$total_repos repositories fetched"

  if [ $total_repos -eq 0 ]; then
    echo "⚠️  No git repositories found in $(pwd)"
  fi
}

# Alias for fetch all
alias gfa='git-fetch-all'

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
        local status=$(git status --porcelain 2>/dev/null || echo "")
        if [ -n "$status" ]; then
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
  local target_dir="$base_path/$repo_name"

  if [ ! -d "$target_dir" ]; then
    echo "❌ Directory '$repo_name' not found in $(pwd)"
    return 1
  fi

  if [ ! -d "$target_dir/.git" ]; then
    echo "❌ '$repo_name' is not a git repository"
    return 1
  fi

  echo "📊 Status for repository: $repo_name"
  echo "─────────────────────────────────────────────────"

  (cd "$target_dir" && {
    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local status=$(git status --porcelain 2>/dev/null || echo "")
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

    if [ -n "$status" ]; then
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
  local target_dir="$base_path/$repo_name"

  if [ ! -d "$target_dir" ]; then
    echo "❌ Directory '$repo_name' not found in $(pwd)"
    return 1
  fi

  if [ ! -d "$target_dir/.git" ]; then
    echo "❌ '$repo_name' is not a git repository"
    return 1
  fi

  echo "🌿 Branches in repository: $repo_name"
  echo "─────────────────────────────────────────────────"

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
  echo "  git-checkout-all <branch>    - Checkout branch in all repos (alias: gcoa)"
  echo "  git-fetch-all [--prune]      - Fetch all repos, optionally with prune (alias: gfa)"
  echo "  git-list-branches-all        - List all branches in all repos (alias: glba)"
  echo "  git-status-all               - Show current branch status (alias: gsa)"
  echo ""
  echo "SINGLE REPO OPERATIONS:"
  echo "  git-status-one <repo>        - Show detailed status for one repo (alias: gso)"
  echo "  git-list-branches-one <repo> - List all branches in one repo (alias: glbo)"
  echo ""
  echo "  git-checkout-all-help        - Show this help message"
  echo ""
  echo "Examples:"
  echo "BULK:"
  echo "  gcoa main                    # Checkout main branch in all repos"
  echo "  gfa                          # Fetch all repos"
  echo "  gfa --prune                  # Fetch all repos with prune"
  echo "  glba                         # List all branches in all repos"
  echo "  gsa                          # Show current status of all repos"
  echo ""
  echo "SINGLE:"
  echo "  gso my-project               # Show detailed status for 'my-project'"
  echo "  glbo my-project              # List all branches in 'my-project'"
  echo ""
  echo "Note: All commands work on subdirectories of the current working directory"
}