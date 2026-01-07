# wt - git worktree manager
# https://github.com/amiller68/worktree

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

wt() {
    if [[ "$1" == "open" || "$1" == "-o" ]]; then
        eval "$(_wt "$@")"
    else
        _wt "$@"
    fi
}

# Get worktree names (handles nested paths like feature/auth/login)
_wt_get_worktrees() {
    local repo=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ -d "$repo/.worktrees" ]] || return
    git worktree list --porcelain 2>/dev/null | grep "^worktree " | cut -d' ' -f2- | while read -r path; do
        [[ "$path" == "$repo/.worktrees"* ]] && echo "${path#$repo/.worktrees/}"
    done
}

# Completion
_wt_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "create list remove open cleanup update version -o" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case $prev in
            open|remove)
                local worktrees=$(_wt_get_worktrees)
                [[ -n "$worktrees" ]] && COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                ;;
            list)
                COMPREPLY=($(compgen -W "--all" -- "$cur"))
                ;;
            update)
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
                ;;
            -o)
                COMPREPLY=($(compgen -W "create" -- "$cur"))
                ;;
        esac
    fi
}
complete -F _wt_complete wt
