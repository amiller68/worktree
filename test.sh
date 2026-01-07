#!/bin/bash
# Simple tests for wt

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# Setup test repo with origin/dev
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git commit --allow-empty -m "init" -q
git branch dev
git remote add origin "$TEST_DIR"  # fake remote pointing to self
git fetch -q origin 2>/dev/null || true

# Source the wt function
source "$HOME/.local/share/worktree/shell/wt.bash" 2>/dev/null || {
    echo "wt not installed, using local"
    # Fallback for testing locally
    export PATH="$(dirname "$0"):$PATH"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((FAIL++))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="$2"
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg (dir does not exist: $dir)"
        ((FAIL++))
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local msg="$2"
    if [[ ! -d "$dir" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg (dir exists: $dir)"
        ((FAIL++))
    fi
}

echo "=== wt tests ==="
echo "Test dir: $TEST_DIR"
echo ""

# Test: create worktree
echo "--- Test: create worktree ---"
_wt create test1 2>/dev/null
assert_dir_exists "$TEST_DIR/.worktrees/test1" "create worktree"
# .git in worktree is a file, not a dir
[[ -f "$TEST_DIR/.worktrees/test1/.git" ]] && echo -e "${GREEN}PASS${NC}: worktree has .git file" && ((PASS++)) || { echo -e "${RED}FAIL${NC}: worktree missing .git file"; ((FAIL++)); }

# Test: list worktrees
echo "--- Test: list worktrees ---"
output=$(_wt list 2>/dev/null)
assert_eq "test1" "$output" "list shows test1"

# Test: create with -o flag outputs cd command
echo "--- Test: create with -o outputs cd ---"
output=$(_wt create test2 -o 2>/dev/null)
[[ "$output" == *"cd "* ]] && result="contains cd" || result="no cd"
assert_eq "contains cd" "$result" "create -o outputs cd command"

# Test: open outputs cd command
echo "--- Test: open outputs cd ---"
output=$(_wt open test1 2>/dev/null)
# Handle macOS /var -> /private/var symlink
expected_path=$(cd "$TEST_DIR/.worktrees/test1" && pwd -P)
[[ "$output" == *"$expected_path"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "open outputs correct cd"

# Test: remove worktree
echo "--- Test: remove worktree ---"
_wt remove test1 2>/dev/null
assert_dir_not_exists "$TEST_DIR/.worktrees/test1" "remove deletes worktree"

# Test: list after remove
echo "--- Test: list after remove ---"
output=$(_wt list 2>/dev/null)
[[ "$output" != *"test1"* ]] && result="test1 gone" || result="test1 still there"
assert_eq "test1 gone" "$result" "list doesn't show removed worktree"

# Test: create -o with error should not leak color codes to stdout
echo "--- Test: create -o error no color leak ---"
# Create a worktree first
_wt create errortest 2>/dev/null
# Try to create same one with -o, capture stdout only
stdout_output=$(_wt create errortest -o 2>/dev/null) || true
# Check stdout doesn't contain escape sequences (color codes)
[[ "$stdout_output" != *$'\033'* ]] && result="clean" || result="has color codes"
assert_eq "clean" "$result" "create -o error has no color codes in stdout"
# Cleanup
_wt remove errortest 2>/dev/null

# Test: nested path create
echo "--- Test: nested path create ---"
_wt create feature/test/nested 2>/dev/null
assert_dir_exists "$TEST_DIR/.worktrees/feature/test/nested" "nested path created"

# Test: list shows nested path
echo "--- Test: list shows nested ---"
output=$(_wt list 2>/dev/null)
[[ "$output" == *"feature/test/nested"* ]] && result="found" || result="not found"
assert_eq "found" "$result" "list shows nested path"

# Cleanup
echo ""
echo "--- Cleanup ---"
rm -rf "$TEST_DIR"
echo "Removed $TEST_DIR"

echo ""
echo "=== Results ==="
echo -e "${GREEN}Passed${NC}: $PASS"
echo -e "${RED}Failed${NC}: $FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
