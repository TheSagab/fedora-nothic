# starship (https://starship.rs) prompt for bash and zsh.
#
# starship comes from Terra. This hook replaces the shell prompt; fish is handled
# separately in /etc/fish/conf.d/starship.fish.
#
# Sourced by /etc/profile (login shells) and, on Fedora, by /etc/bashrc for
# interactive bash. Guarded on interactivity, because a prompt in a
# non-interactive shell is at best wasted work.
#
# If you use zsh as a non-login interactive shell, add this to ~/.zshrc:
#   eval "$(starship init zsh)"

case $- in
    *i*)
        if command -v starship >/dev/null 2>&1; then
            if [ -n "${ZSH_VERSION-}" ]; then
                eval "$(starship init zsh)"
            elif [ -n "${BASH_VERSION-}" ]; then
                eval "$(starship init bash)"
            fi
        fi
        ;;
esac
