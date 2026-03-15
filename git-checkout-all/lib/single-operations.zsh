# Git Checkout All Plugin - Single Repository Operations
# Functions that operate on a single specified repository

# Function to fetch a single repository
git-fetch-one() {
  if [ -z "$1" ]; then
    echo "Usage: git-fetch-one [--prune] [--pull] [--remove-local] <repo-name>"
    echo "Example: git-fetch-one my-project"
    echo "Example: git-fetch-one --pull my-project"
    echo "Example: git-fetch-one --prune --pull my-project"
    echo "Example: git-fetch-one --prune --remove-local my-project"
    return 1
  fi

  local use_prune=false
  local use_pull=false
  local use_remove_local=false
  local repo_name=""
  local base_path="$(pwd)"

  # Parse options and arguments
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
      --remove-local)
        use_remove_local=true
        shift
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: git-fetch-one [--prune] [--pull] [--remove-local] <repo-name>"
        return 1
        ;;
      *)
        if [ -z "$repo_name" ]; then
          repo_name="$1"
        else
          echo "Error: Multiple repository names provided"
          echo "Usage: git-fetch-one [--prune] [--pull] [--remove-local] <repo-name>"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate repository name is provided
  if [ -z "$repo_name" ]; then
    echo "Usage: git-fetch-one [--prune] [--pull] [--remove-local] <repo-name>"
    echo "Example: git-fetch-one my-project"
    echo "Example: git-fetch-one --pull my-project"
    echo "Example: git-fetch-one --prune --pull my-project"
    echo "Example: git-fetch-one --prune --remove-local my-project"
    return 1
  fi

  # Validate repository exists
  if ! _validate_repository "$repo_name" "$base_path"; then
    return 1
  fi

  local target_dir="$base_path/$repo_name"
  local operation_desc="Fetching"
  
  if [ "$use_prune" = true ]; then
    operation_desc="$operation_desc with prune"
  fi
  
  if [ "$use_pull" = true ]; then
    operation_desc="$operation_desc and pulling"
  fi

  if [ "$use_remove_local" = true ]; then
    operation_desc="$operation_desc and removing gone local branches"
  fi

  _print_header "🔄 $operation_desc repository: $repo_name"

  # Load target branches configuration once
  local config_result=$(_load_target_branches_config)
  local config_source="${config_result%%|*}"
  local branches_str="${config_result#*|}"
  local target_branches=(${(s: :)branches_str})
  
  # Log configuration once if using --pull
  if [ "$use_pull" = true ]; then
    echo "🔧 Target branches loaded from: $config_source" >&2
    echo "📋 Branches: ${target_branches[*]}" >&2
  fi

  # Process the single repository
  _process_repository_fetch "$target_dir" "$use_prune" "$use_pull" "$use_remove_local" "${target_branches[@]}"
  local exit_code=$?
  
  if [ $exit_code -eq -1 ]; then
    echo ""
    echo "❌ Fetch operation failed for $repo_name"
    return 1
  elif [ "$use_pull" = true ]; then
    local pull_count=$exit_code
    echo ""
    if [ $pull_count -gt 0 ]; then
      echo "✅ Repository fetched successfully, $pull_count branch(es) pulled"
    else
      echo "✅ Repository fetched successfully, no branches needed pulling"
    fi
  else
    echo ""
    echo "✅ Repository fetched successfully"
  fi
}

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

# Function to list latest tags in one or more repositories (comma-separated)
# Single repo: lists 5 latest tags. Multiple repos: lists latest tag only per repo.
git-list-tag-one() {
  if [ -z "$1" ]; then
    echo "Usage: git-list-tag-one <repo-name> [repo-name2,...]"
    echo "Example: git-list-tag-one my-project"
    echo "Example: git-list-tag-one my-project,my-project-2   # multiple repos: latest tag only"
    return 1
  fi

  local base_path="$(pwd)"
  # Parse comma-separated repo names
  local repo_names=("${(@s:,:)1}")
  # Trim whitespace from each name
  repo_names=("${(@)repo_names//[[:space:]]/}")
  local num_repos=${#repo_names[@]}

  # Validate all repositories exist
  for repo_name in "${repo_names[@]}"; do
    if [ -z "$repo_name" ]; then
      continue
    fi
    if ! _validate_repository "$repo_name" "$base_path"; then
      return 1
    fi
  done

  if [ $num_repos -eq 1 ]; then
    # Single repo: list 5 latest tags (original behavior)
    local repo_name="${repo_names[1]}"
    local target_dir="$base_path/$repo_name"

    _print_header "🏷️  Latest tags in repository: $repo_name"

    (cd "$target_dir" && {
      echo "🔄 Fetching tags from remote..."
      git fetch --tags --quiet 2>/dev/null

      local tags=$(git tag -l 'v*' | sort -V -r | head -n 5)

      if [ -n "$tags" ]; then
        echo ""
        echo "Latest 5 tags:"
        echo "$tags" | while IFS= read -r tag; do
          local tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
          echo "  🏷️  $tag ($tag_date)"
        done
      else
        echo ""
        echo "⚠️  No tags found in this repository"
      fi
    })
  else
    # Multiple repos: list latest tag only per repo (like ggtla)
    _print_header "🔍 Latest tag in repositories: ${repo_names[*]}"

    for repo_name in "${repo_names[@]}"; do
      [ -z "$repo_name" ] && continue
      local target_dir="$base_path/$repo_name"

      (cd "$target_dir" && {
        git fetch --tags --quiet 2>/dev/null
        local latest_tag=$(git tag -l 'v*' | sort -V -r | head -n 1)
        if [ -n "$latest_tag" ]; then
          local tag_date=$(git log -1 --format=%ai "$latest_tag" 2>/dev/null | cut -d' ' -f1)
          echo "📁 $repo_name: 🏷️  $latest_tag ($tag_date)"
        else
          echo "📁 $repo_name: ⚠️  No tags found"
        fi
      })
    done
  fi
}
