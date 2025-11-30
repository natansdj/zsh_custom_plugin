#!/usr/bin/env zsh
# Test script for dynamic target branches configuration
# This script demonstrates how the configuration system works

echo "🧪 Testing git-checkout-all Target Branches Configuration"
echo "=========================================================="
echo

# Source the utility functions
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/utils.zsh"

# Test 1: Default configuration
echo "Test 1: Default Configuration (no env var, no config file)"
echo "-----------------------------------------------------------"
unset GIT_CHECKOUT_ALL_TARGET_BRANCHES
CONFIG_FILE_BACKUP=""
if [ -f "${HOME}/.git-checkout-all.conf" ]; then
  CONFIG_FILE_BACKUP="${HOME}/.git-checkout-all.conf.testbackup"
  mv "${HOME}/.git-checkout-all.conf" "$CONFIG_FILE_BACKUP"
fi

echo "Default branches:"
_load_target_branches_config
echo

# Test 2: Environment variable
echo "Test 2: Environment Variable Configuration"
echo "-----------------------------------------------------------"
export GIT_CHECKOUT_ALL_TARGET_BRANCHES="develop,staging,main"
echo "Set: GIT_CHECKOUT_ALL_TARGET_BRANCHES='develop,staging,main'"
echo "Loaded branches:"
_load_target_branches_config
echo

# Test 3: Config file
echo "Test 3: Config File Configuration"
echo "-----------------------------------------------------------"
unset GIT_CHECKOUT_ALL_TARGET_BRANCHES
cat > "${HOME}/.git-checkout-all.conf" << 'EOF'
# Test configuration
develop
test
staging
production
EOF

echo "Config file (~/.git-checkout-all.conf):"
cat "${HOME}/.git-checkout-all.conf"
echo
echo "Loaded branches:"
_load_target_branches_config
echo

# Test 4: Priority (env var overrides config file)
echo "Test 4: Priority Test (Environment Variable vs Config File)"
echo "-----------------------------------------------------------"
export GIT_CHECKOUT_ALL_TARGET_BRANCHES="main,prod"
echo "Environment: GIT_CHECKOUT_ALL_TARGET_BRANCHES='main,prod'"
echo "Config file still exists with: develop, test, staging, production"
echo
echo "Loaded branches (should use env var):"
_load_target_branches_config
echo

# Test 5: Comma-separated with spaces
echo "Test 5: Comma-separated with Spaces"
echo "-----------------------------------------------------------"
export GIT_CHECKOUT_ALL_TARGET_BRANCHES="develop, staging , main,  production"
echo "Set: GIT_CHECKOUT_ALL_TARGET_BRANCHES='develop, staging , main,  production'"
echo "Loaded branches (spaces should be trimmed):"
_load_target_branches_config
echo

# Cleanup
echo "🧹 Cleanup"
echo "-----------------------------------------------------------"
rm -f "${HOME}/.git-checkout-all.conf"
if [ -n "$CONFIG_FILE_BACKUP" ]; then
  mv "$CONFIG_FILE_BACKUP" "${HOME}/.git-checkout-all.conf"
  echo "Restored original config file"
else
  echo "Removed test config file"
fi
unset GIT_CHECKOUT_ALL_TARGET_BRANCHES
echo

echo "✅ All tests completed!"
echo
echo "Usage:"
echo "  1. Set environment variable in ~/.zshrc:"
echo "     export GIT_CHECKOUT_ALL_TARGET_BRANCHES='develop,staging,main'"
echo
echo "  2. Or create config file ~/.git-checkout-all.conf:"
echo "     echo 'develop' > ~/.git-checkout-all.conf"
echo "     echo 'staging' >> ~/.git-checkout-all.conf"
echo "     echo 'main' >> ~/.git-checkout-all.conf"
echo
echo "  3. Or use defaults: develop-pjp, develop, staging, master"
