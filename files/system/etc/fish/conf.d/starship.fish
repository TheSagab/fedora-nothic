# starship (https://starship.rs) prompt for fish.
#
# starship comes from Terra. Its init replaces the fish prompt; see
# /etc/profile.d/starship.sh for the bash and zsh equivalent.
#
# Guarded on interactivity: a prompt is only wanted in an interactive shell, and
# unlike mise's activation this has no business running in scripts.

if status is-interactive
    if command -q starship
        starship init fish | source
    end
end
