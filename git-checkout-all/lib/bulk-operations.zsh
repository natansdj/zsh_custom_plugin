# Git Checkout All Plugin - Bulk Operations
# Functions that operate on all repositories in current directory

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

# Function to checkout branch in selected repositories only
git-checkout-selected() {
  local create_branch=false
  local branch_name=""
  local repo_list=""
  local base_path="$(pwd)"
  local success_count=0
  local total_repos=0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -b)
        create_branch=true
        shift
        ;;
      --repo=*)
        repo_list="${1#*=}"
        shift
        ;;
      --repo)
        if [ -z "$2" ]; then
          echo "Error: --repo requires a value"
          echo "Usage: git-checkout-selected [-b] <branch-name> --repo=repo1,repo2"
          return 1
        fi
        repo_list="$2"
        shift 2
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: git-checkout-selected [-b] <branch-name> --repo=repo1,repo2"
        return 1
        ;;
      *)
        if [ -z "$branch_name" ]; then
          branch_name="$1"
        else
          echo "Error: Multiple branch names provided"
          echo "Usage: git-checkout-selected [-b] <branch-name> --repo=repo1,repo2"
          return 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$branch_name" ]; then
    echo "Usage: git-checkout-selected [-b] <branch-name> --repo=repo1,repo2"
    return 1
  fi

  if [ -z "$repo_list" ]; then
    echo "Error: --repo is required"
    echo "Usage: git-checkout-selected [-b] <branch-name> --repo=repo1,repo2"
    return 1
  fi

  local selected_repos=(${(s:,:)repo_list})
  selected_repos=("${(@)selected_repos//[[:space:]]/}")

  for repo_name in "${selected_repos[@]}"; do
    if ! _validate_repository "$repo_name" "$base_path"; then
      return 1
    fi
  done

  _print_header "🔍 Processing selected repositories in $(pwd)..."
  if [ "$create_branch" = true ]; then
    echo "🆕 Creating and checking out new branch: $branch_name"
  else
    echo "🌿 Attempting to checkout branch: $branch_name"
  fi

  for repo_name in "${selected_repos[@]}"; do
    local target_dir="$base_path/$repo_name"
    total_repos=$((total_repos + 1))

    echo -n "📁 $repo_name: "
    (cd "$target_dir" && {
      if [ "$create_branch" = true ]; then
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
        if _branch_exists_local "$branch_name"; then
          if git checkout "$branch_name" >/dev/null 2>&1; then
            echo "✅ Success"
            success_count=$((success_count + 1))
          else
            echo "❌ Failed to checkout"
          fi
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
  done

  if [ "$create_branch" = true ]; then
    _print_summary "$success_count" "$total_repos" "branches created"
  else
    _print_summary "$success_count" "$total_repos" "updated"
  fi
}

# Function to fetch all repositories
git-fetch-all() {
  local base_path="$(pwd)"
  local use_prune=false
  local use_pull=false
  local use_remove_local=false
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
      --remove-local)
        use_remove_local=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        echo "Usage: git-fetch-all [--prune] [--pull] [--remove-local]"
        return 1
        ;;
    esac
  done

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

  _print_header "🔄 $operation_desc all repositories in $(pwd)..."

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

  for dir in "$base_path"/*/; do
    if [ -d "$dir/.git" ]; then
      total_repos=$((total_repos + 1))
      
      # Process the repository using the utility function
      _process_repository_fetch "$dir" "$use_prune" "$use_pull" "$use_remove_local" "${target_branches[@]}"
      local exit_code=$?
      
      if [ $exit_code -ne -1 ]; then
        success_count=$((success_count + 1))
        if [ "$use_pull" = true ] && [ $exit_code -gt 0 ]; then
          pull_count=$((pull_count + exit_code))
        fi
      fi
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

# List latest tag from all repositories
git-list-tag-all() {
  local base_path="$(pwd)"
  local success_count=0
  local total_repos=0

  _print_header "🔍 Listing latest tag from repositories in $(pwd)..."

  # Get list of git repositories
  local repos=($(_get_git_repositories "$base_path"))
  
  if [ ${#repos[@]} -eq 0 ]; then
    echo "❌ No git repositories found in current directory"
    return 1
  fi

  _print_header "📊 Found ${#repos[@]} git repositories"

  for repo_path in "${repos[@]}"; do
    total_repos=$((total_repos + 1))
    local repo_name=$(basename "$repo_path")
    
    (cd "$repo_path" && {
      # Fetch tags from remote to ensure we have the latest
      git fetch --tags --quiet 2>/dev/null
      
      # Get the latest tag only
      local latest_tag=$(git tag -l 'v*' | sort -V -r | head -n 1)
      
      if [ -n "$latest_tag" ]; then
        local tag_date=$(git log -1 --format=%ai "$latest_tag" 2>/dev/null | cut -d' ' -f1)
        echo "📁 $repo_name: 🏷️  $latest_tag ($tag_date)"
        success_count=$((success_count + 1))
      else
        echo "📁 $repo_name: ⚠️  No tags found"
      fi
    })
  done

  _print_header "📊 Summary: $success_count/$total_repos repositories with tags"
}

# Create new tag by incrementing from latest tag
git-tag-create() {
  if [ $# -lt 2 ]; then
    echo "Usage: git-tag-create <increment-type> <repo-name> [--push]"
    echo "  increment-type: patch, minor, or major"
    echo "  --push: Push the tag to remote after creation"
    echo ""
    echo "Examples:"
    echo "  git-tag-create patch my-repo         # v1.0.1 -> v1.0.2"
    echo "  git-tag-create minor my-repo         # v1.0.1 -> v1.1.0"
    echo "  git-tag-create major my-repo         # v1.0.1 -> v2.0.0"
    echo "  git-tag-create patch my-repo --push  # Create and push"
    return 1
  fi

  local increment_type="$1"
  local repo_name="$2"
  local should_push=false
  local base_path="$(pwd)"

  # Check for --push flag
  if [ "$3" = "--push" ]; then
    should_push=true
  fi

  # Validate increment type
  if [[ ! "$increment_type" =~ ^(patch|minor|major)$ ]]; then
    echo "❌ Invalid increment type: $increment_type"
    echo "   Must be one of: patch, minor, major"
    return 1
  fi

  # Validate repository exists
  if ! _validate_repository "$repo_name" "$base_path"; then
    return 1
  fi

  local target_dir="$base_path/$repo_name"
  
  _print_header "🏷️  Creating new $increment_type tag for: $repo_name"

  (cd "$target_dir" && {
    # Fetch tags from remote to ensure we have the latest
    echo "🔄 Fetching latest tags from remote..."
    git fetch --tags --quiet 2>/dev/null
    
    # Get the latest tag
    local latest_tag=$(git tag -l 'v*' | sort -V -r | head -n 1)
    
    if [ -z "$latest_tag" ]; then
      echo "❌ No existing tags found. Cannot determine next version."
      echo "   Consider creating an initial tag like v1.0.0"
      return 1
    fi
    
    echo "📌 Current latest tag: $latest_tag"
    
    # Parse version numbers (assuming format vMAJOR.MINOR.PATCH)
    # Remove 'v' prefix and split by dots
    local version_string="${latest_tag#v}"
    local version_parts=(${(s:.:)version_string})
    
    if [ ${#version_parts[@]} -eq 3 ]; then
      local major="${version_parts[1]}"
      local minor="${version_parts[2]}"
      local patch="${version_parts[3]}"
      
      # Increment based on type
      case "$increment_type" in
        patch)
          patch=$((patch + 1))
          ;;
        minor)
          minor=$((minor + 1))
          patch=0
          ;;
        major)
          major=$((major + 1))
          minor=0
          patch=0
          ;;
      esac
      
      local new_tag="v${major}.${minor}.${patch}"
      
      # Check if tag already exists
      if git rev-parse "$new_tag" >/dev/null 2>&1; then
        echo "❌ Tag $new_tag already exists"
        return 1
      fi
      
      # Create the tag
      echo "🆕 Creating new tag: $new_tag"
      if git tag "$new_tag"; then
        echo "✅ Tag created successfully: $new_tag"
        
        # Push if requested
        if [ "$should_push" = true ]; then
          echo "📤 Pushing tag to remote..."
          if git push origin "$new_tag"; then
            echo "✅ Tag pushed to remote successfully"
          else
            echo "❌ Failed to push tag to remote"
            return 1
          fi
        else
          echo "💡 Tag created locally. Use 'git push origin $new_tag' to push to remote"
        fi
      else
        echo "❌ Failed to create tag"
        return 1
      fi
    else
      echo "❌ Latest tag format not recognized: $latest_tag"
      echo "   Expected format: vMAJOR.MINOR.PATCH (e.g., v1.0.1)"
      return 1
    fi
  })
}

# Create and push tag (convenience function)
git-tag-create-push() {
  if [ $# -lt 2 ]; then
    echo "Usage: git-tag-create-push <increment-type> <repo-name>"
    echo "  increment-type: patch, minor, or major"
    echo ""
    echo "This is a convenience command that creates and pushes the tag."
    echo "Equivalent to: git-tag-create <increment-type> <repo-name> --push"
    echo ""
    echo "Examples:"
    echo "  git-tag-create-push patch my-repo    # v1.0.1 -> v1.0.2 and push"
    echo "  git-tag-create-push minor my-repo    # v1.0.1 -> v1.1.0 and push"
    echo "  git-tag-create-push major my-repo    # v1.0.1 -> v2.0.0 and push"
    return 1
  fi

  # Simply call git-tag-create with --push flag
  git-tag-create "$1" "$2" --push
}
