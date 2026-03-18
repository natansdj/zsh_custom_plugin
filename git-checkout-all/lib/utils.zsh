# Git Checkout All Plugin - Utility Functions
# Shared helper functions for git operations

# Load target branches configuration
# Priority: 1. Environment variable, 2. Config file, 3. Default
_load_target_branches_config() {
  local config_file="${HOME}/.git-checkout-all.conf"
  local branches=()
  local config_source=""
  
  # Priority 1: Check environment variable
  if [ -n "$GIT_CHECKOUT_ALL_TARGET_BRANCHES" ]; then
    # Split by comma or space
    IFS=',' read -rA branches <<< "$GIT_CHECKOUT_ALL_TARGET_BRANCHES"
    # Trim whitespace from each branch
    branches=("${(@)branches//[[:space:]]/}")
    config_source="environment variable"
  # Priority 2: Check config file
  elif [ -f "$config_file" ]; then
    # Read branches from config file (one per line or comma-separated)
    while IFS= read -r line || [ -n "$line" ]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # Handle comma-separated values in a line
      IFS=',' read -rA line_branches <<< "$line"
      for branch in "${line_branches[@]}"; do
        # Trim whitespace
        branch="${branch//[[:space:]]/}"
        [ -n "$branch" ] && branches+=("$branch")
      done
    done < "$config_file"
    config_source="config file (~/.git-checkout-all.conf)"
  fi
  
  # Priority 3: Use defaults if nothing configured
  if [ ${#branches[@]} -eq 0 ]; then
    branches=("develop" "staging" "master")
    config_source="defaults"
  fi
  
  # Output format: config_source|branch1,branch2,branch3
  echo "${config_source}|${branches[*]}"
}

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

# Remove local branches whose upstream remote branch is gone
_remove_gone_local_branches() {
  local current_branch=$(git branch --show-current 2>/dev/null)
  local deleted_count=0
  local deleted_branches=()

  while IFS='|' read -r local_branch upstream_track; do
    [ -z "$local_branch" ] && continue

    if [[ "$upstream_track" == *"[gone]"* ]]; then
      if [ "$local_branch" = "$current_branch" ]; then
        continue
      fi

      if git branch -D "$local_branch" >/dev/null 2>&1; then
        deleted_count=$((deleted_count + 1))
        deleted_branches+=("$local_branch")
      fi
    fi
  done < <(git for-each-ref --format='%(refname:short)|%(upstream:track)' refs/heads 2>/dev/null)

  echo "$deleted_count:${deleted_branches[*]}"
}

# Pull updates for specific branches if available
_pull_branch_updates() {
  local branches=("$@")
  local pull_count=0
  local updated_branches=()
  local current_branch=$(git branch --show-current 2>/dev/null)
  local original_branch="$current_branch"
  
  for branch in "${branches[@]}"; do
    local upstream="origin/$branch"
    
    # Check if branch exists locally and on remote
    if _branch_exists_local "$branch" && git rev-parse --verify "$upstream" >/dev/null 2>&1; then
      local local_commit=$(git rev-parse "$branch" 2>/dev/null)
      local remote_commit=$(git rev-parse "$upstream" 2>/dev/null)
      
      # If there are updates available
      if [ "$local_commit" != "$remote_commit" ]; then
        # Switch to the branch to update it
        if git checkout "$branch" >/dev/null 2>&1; then
          # Try to fast-forward
          if _can_fast_forward "$upstream"; then
            if git merge --ff-only "$upstream" >/dev/null 2>&1; then
              updated_branches+=("$branch")
              pull_count=$((pull_count + 1))
            fi
          fi
        fi
      fi
    fi
  done
  
  # Return to original branch if it existed
  if [ -n "$original_branch" ] && [ "$original_branch" != "$(git branch --show-current 2>/dev/null)" ]; then
    git checkout "$original_branch" >/dev/null 2>&1
  fi
  
  # Return results
  echo "$pull_count:${updated_branches[*]}"
}

# Process fetch and pull for a single repository
_process_repository_fetch() {
  local repo_path="$1"
  local use_prune="$2"
  local use_pull="$3"
  local use_remove_local="$4"
  shift 4
  local target_branches=("$@")
  local repo_name=$(basename "$repo_path")
  local original_dir="$PWD"

  typeset -g GCA_LAST_FETCH_FAILED=0
  typeset -g GCA_LAST_PULL_COUNT=0
  typeset -g GCA_LAST_REMOVED_COUNT=0
  
  echo -n "📁 $repo_name: "

  if ! cd "$repo_path" >/dev/null 2>&1; then
    echo "❌ Failed"
    GCA_LAST_FETCH_FAILED=1
    cd "$original_dir" >/dev/null 2>&1
    return 1
  fi

  local fetch_options=""
  if [ "$use_prune" = true ] || [ "$use_remove_local" = true ]; then
    fetch_options="--prune"
  fi

  if ! git fetch $fetch_options >/dev/null 2>&1; then
    echo "❌ Failed"
    GCA_LAST_FETCH_FAILED=1
    cd "$original_dir" >/dev/null 2>&1
    return 1
  fi

  echo -n "✅ Fetched"

  if [ "$use_pull" = true ]; then
    local pull_result=$(_pull_branch_updates "${target_branches[@]}")
    local branch_pull_count=$(echo "$pull_result" | cut -d: -f1)
    local updated_branches=$(echo "$pull_result" | cut -d: -f2)
    GCA_LAST_PULL_COUNT="$branch_pull_count"

    if [ "$branch_pull_count" -gt 0 ]; then
      echo -n " + 🔄 Pulled $branch_pull_count branch(es): $updated_branches"
    else
      local branch_list=$(echo "${target_branches[@]}" | sed 's/ /\//g')
      echo -n " (no updates for $branch_list)"
    fi
  fi

  if [ "$use_remove_local" = true ]; then
    local remove_result=$(_remove_gone_local_branches)
    local removed_count=$(echo "$remove_result" | cut -d: -f1)
    local removed_branches=$(echo "$remove_result" | cut -d: -f2)
    GCA_LAST_REMOVED_COUNT="$removed_count"

    if [ "$removed_count" -gt 0 ]; then
      echo " + 🧹 Removed $removed_count local branch(es): $removed_branches"
    else
      echo " + 🧹 No local gone branches"
    fi
  else
    echo ""
  fi

  cd "$original_dir" >/dev/null 2>&1
  return 0
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
