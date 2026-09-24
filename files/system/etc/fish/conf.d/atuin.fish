# atuin (https://atuin.sh) shell history for fish.
#
# atuin replaces the history search with a searchable database. Its init sets up
# the Ctrl-R binding; see /etc/profile.d/atuin.sh for the bash and zsh
# equivalent.
#
# Note that atuin takes Ctrl-R. If you would rather have fzf's history widget
# (fzf is installed), do not source this file and use fzf's key bindings
# instead: `fzf --fish | source` in your own config.

if status is-interactive
    if command -q atuin
        atuin init fish | source
    end
end
