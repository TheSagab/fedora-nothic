# atuin (https://atuin.sh) shell history for bash and zsh.
#
# This hook installs atuin's Ctrl-R history search; fish is handled separately in
# /etc/fish/conf.d/atuin.fish. atuin keeps its own database under
# ~/.local/share/atuin and imports your existing history the first time you run
# it.
#
# If you use zsh as a non-login interactive shell, add this to ~/.zshrc:
#   eval "$(atuin init zsh)"

case $- in
    *i*)
        if command -v atuin >/dev/null 2>&1; then
            if [ -n "${ZSH_VERSION-}" ]; then
                eval "$(atuin init zsh)"
            elif [ -n "${BASH_VERSION-}" ]; then
                eval "$(atuin init bash)"
            fi
        fi
        ;;
esac
