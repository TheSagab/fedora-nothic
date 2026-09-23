# mise (https://mise.jdx.dev) shell activation.
#
# mise itself is installed at /usr/bin/mise and manages per-project tool
# versions under ~/.local/share/mise. This hook makes `mise` put the right
# tool versions on PATH as you move between directories.
#
# Sourced by /etc/profile (bash, zsh and other POSIX login shells) and, on
# Fedora, by /etc/bashrc for interactive bash. fish is handled separately in
# /etc/fish/conf.d/mise.fish.
#
# If you use zsh as a non-login interactive shell, add this to ~/.zshrc:
#   eval "$(mise activate zsh)"

if command -v mise >/dev/null 2>&1; then
    if [ -n "${ZSH_VERSION-}" ]; then
        eval "$(mise activate zsh)"
    elif [ -n "${BASH_VERSION-}" ]; then
        eval "$(mise activate bash)"
    fi
fi
