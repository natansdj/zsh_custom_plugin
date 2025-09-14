# Git Checkout All Plugin
# Author: Your Name
# Description: Checkout the same branch across all repositories in current directory

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

# Function to show current branch in all repositories
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

# Help function
git-checkout-all-help() {
  echo "Git Checkout All Plugin - Available Commands:"
  echo "─────────────────────────────────────────────────"
  echo "git-checkout-all <branch>  - Checkout branch in all repos (alias: gcoa)"
  echo "git-list-branches-all      - List all branches in all repos (alias: glba)"
  echo "git-status-all             - Show current branch status (alias: gsa)"
  echo "git-checkout-all-help      - Show this help message"
  echo ""
  echo "Examples:"
  echo "  gcoa main                 # Checkout main branch in all repos in current directory"
  echo "  gcoa feature/new-feature  # Checkout feature branch in all repos in current directory"
  echo "  glba                      # List all branches in current directory repos"
  echo "  gsa                       # Show current status of repos in current directory"
  echo ""
  echo "Note: All commands work on subdirectories of the current working directory"
}
