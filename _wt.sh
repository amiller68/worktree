#!/bin/bash

# Git Worktree Setup Script for Multiple Claude Code Instances
# This script helps create separate git worktrees for working with multiple
# instances of Claude Code on any git repository

set -e

# Install location (set by installer)
INSTALL_DIR="${WORKTREE_INSTALL_DIR:-$HOME/.local/share/worktree}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: wt [-o] <command> [worktree-name] [branch-name]"
    echo ""
    echo "Manages git worktrees within the current repository's .worktrees/ directory."
    echo "Run this command from anywhere inside a git repository."
    echo ""
    echo "Options:"
    echo "  -o                      - Open: cd to worktree directory after create"
    echo ""
    echo "Commands:"
    echo "  create <name> [branch]  - Create a new worktree (branch defaults to new branch from origin/dev)"
    echo "  list [--all]            - List worktrees (--all shows all git worktrees)"
    echo "  remove <name>           - Remove a worktree"
    echo "  open <name>             - cd to worktree directory"
    echo "  cleanup                 - Remove all worktrees"
    echo "  update [--force]        - Update wt to latest version"
    echo "  version                 - Show version info"
    echo ""
    echo "Examples:"
    echo "  wt create feature/auth/login"
    echo "  wt -o create feature-branch   # create and cd"
    echo "  wt open feature/auth/login    # cd to existing"
    echo "  wt list"
    echo "  wt update"
}

detect_repo() {
    if ! REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null); then
        echo -e "${RED}Error: Not inside a git repository${NC}" >&2
        exit 1
    fi
    WORKTREES_BASE_DIR="$REPO_DIR/.worktrees"
}

ensure_worktrees_excluded() {
    local exclude_file="$REPO_DIR/.git/info/exclude"
    if [ -f "$exclude_file" ]; then
        if ! grep -q "^\.worktrees$" "$exclude_file" 2>/dev/null; then
            echo ".worktrees" >> "$exclude_file"
        fi
    fi
}

# Get list of worktree names in .worktrees (handles nested paths like feature/auth/login)
get_worktree_names() {
    if [ ! -d "$WORKTREES_BASE_DIR" ]; then
        return
    fi
    # Use git worktree list and filter for .worktrees paths
    git worktree list --porcelain 2>/dev/null | grep "^worktree " | cut -d' ' -f2- | while read -r path; do
        case "$path" in
            "$WORKTREES_BASE_DIR"*)
                echo "${path#$WORKTREES_BASE_DIR/}"
                ;;
        esac
    done
}

# Resolve worktree name to full path
resolve_worktree_path() {
    local name="$1"
    local path="$WORKTREES_BASE_DIR/$name"

    # Check if it exists in .worktrees
    if [ -d "$path" ] && [ -f "$path/.git" ]; then
        echo "$path"
        return 0
    fi

    return 1
}

create_worktree() {
    local name="$1"
    local branch="${2:-$name}"
    local worktree_path="$WORKTREES_BASE_DIR/$name"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Worktree name is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    if [ -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' already exists at $worktree_path${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}Creating worktree '$name' from branch '$branch'...${NC}" >&2

    # Ensure .worktrees is in .git/info/exclude
    ensure_worktrees_excluded

    # Create the base directory if it doesn't exist
    mkdir -p "$WORKTREES_BASE_DIR"

    # Change to repository directory and create worktree
    cd "$REPO_DIR"

    # If using default branch name (same as worktree), check if branch exists
    # Redirect git output to stderr so it doesn't interfere with cd command
    if [ "$branch" = "$name" ]; then
        # Check if branch exists locally or remotely
        if git show-ref --verify --quiet "refs/heads/$name" || git show-ref --verify --quiet "refs/remotes/origin/$name"; then
            echo -e "${YELLOW}Using existing branch '$name'${NC}" >&2
            git worktree add "$worktree_path" "$name" >&2
        else
            echo -e "${YELLOW}Creating new branch '$name' from origin/dev${NC}" >&2
            git worktree add -b "$name" "$worktree_path" origin/dev >&2
        fi
    else
        git worktree add "$worktree_path" "$branch" >&2
    fi

    echo -e "${GREEN}Worktree created successfully!${NC}" >&2
    echo -e "${YELLOW}Path: $worktree_path${NC}" >&2

    if [ "$OPEN_AFTER" = "true" ]; then
        open_worktree "$name"
    else
        echo -e "${YELLOW}To open: wt open $name${NC}" >&2
    fi
}

list_worktrees() {
    local show_all="$1"

    if [ "$show_all" = "--all" ]; then
        echo -e "${BLUE}All git worktrees:${NC}"
        cd "$REPO_DIR"
        git worktree list
    else
        local worktrees=$(get_worktree_names)
        if [ -z "$worktrees" ]; then
            echo "No worktrees found in .worktrees/"
        else
            echo "$worktrees"
        fi
    fi
}

remove_worktree() {
    local pattern="$1"

    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: Worktree name or pattern is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    # Convert glob to regex: * -> .*, ? -> .
    local regex=$(echo "$pattern" | sed 's/\*/.\*/g; s/?/./g')

    # Get matching worktrees
    local matches=$(get_worktree_names | grep -E "^${regex}$" 2>/dev/null)

    # If no regex match, try exact match for backwards compatibility
    if [ -z "$matches" ]; then
        local worktree_path=$(resolve_worktree_path "$pattern")
        if [ -n "$worktree_path" ]; then
            matches="$pattern"
        fi
    fi

    if [ -z "$matches" ]; then
        echo -e "${RED}Error: No worktrees match '$pattern'${NC}" >&2
        exit 1
    fi

    # Count matches
    local count=$(echo "$matches" | wc -l | tr -d ' ')

    # Show what will be removed
    echo -e "${YELLOW}Removing $count worktree(s):${NC}" >&2
    echo "$matches" | while read -r name; do
        echo "  - $name" >&2
    done

    # Remove each
    cd "$REPO_DIR"
    echo "$matches" | while read -r name; do
        local path="$WORKTREES_BASE_DIR/$name"
        git worktree remove "$path" >&2
    done

    echo -e "${GREEN}Done!${NC}" >&2
}

open_worktree() {
    local name="$1"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Worktree name is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    local worktree_path=$(resolve_worktree_path "$name")
    if [ -z "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' does not exist${NC}" >&2
        exit 1
    fi

    # Output cd command for eval (stdout only)
    echo "cd \"$worktree_path\""
}

cleanup_worktrees() {
    echo -e "${YELLOW}Cleaning up all worktrees...${NC}"

    if [ -d "$WORKTREES_BASE_DIR" ]; then
        cd "$REPO_DIR"

        # Remove all worktrees
        for worktree_dir in "$WORKTREES_BASE_DIR"/*; do
            if [ -d "$worktree_dir" ]; then
                local name=$(basename "$worktree_dir")
                echo "Removing worktree: $name"
                git worktree remove "$worktree_dir" 2>/dev/null || true
            fi
        done

        # Remove the base directory
        rm -rf "$WORKTREES_BASE_DIR"
    fi

    echo -e "${GREEN}Cleanup complete!${NC}"
}

get_version() {
    local manifest="$INSTALL_DIR/manifest.toml"
    if [ -f "$manifest" ]; then
        grep '^version' "$manifest" | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

show_version() {
    local version=$(get_version)
    echo -e "${BLUE}wt${NC} $version"
}

update_worktree() {
    local force="$1"

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo -e "${RED}Error: Install directory is not a git repository${NC}"
        echo "Reinstall with: curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash"
        exit 1
    fi

    local old_version=$(get_version)
    echo -e "${BLUE}Updating wt...${NC}"

    cd "$INSTALL_DIR"

    if [ "$force" = "--force" ] || [ "$force" = "-f" ]; then
        echo -e "${YELLOW}Force updating...${NC}"
        git fetch origin main
        git reset --hard origin/main
    else
        git pull --ff-only origin main
    fi

    local new_version=$(get_version)
    if [ "$old_version" = "$new_version" ]; then
        echo -e "${GREEN}Already up to date ($new_version)${NC}"
    else
        echo -e "${GREEN}Updated: $old_version -> $new_version${NC}"
    fi
}

# Parse arguments
OPEN_AFTER="false"

# Check for flags
while [[ "$1" == -* ]]; do
    case "$1" in
        -o)
            OPEN_AFTER="true"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown flag $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Commands that don't need a git repo
case "$1" in
update)
    update_worktree "$2"
    exit 0
    ;;
version)
    show_version
    exit 0
    ;;
esac

# All other commands need a git repo
detect_repo

case "$1" in
create)
    # Handle -o flag in any position
    _name="" _branch=""
    shift  # remove 'create'
    for arg in "$@"; do
        if [[ "$arg" == "-o" ]]; then
            OPEN_AFTER="true"
        elif [[ -z "$_name" ]]; then
            _name="$arg"
        else
            _branch="$arg"
        fi
    done
    create_worktree "$_name" "$_branch"
    ;;
list)
    list_worktrees "$2"
    ;;
remove)
    remove_worktree "$2"
    ;;
open)
    open_worktree "$2"
    ;;
cleanup)
    cleanup_worktrees
    ;;
*)
    print_usage
    exit 1
    ;;
esac
