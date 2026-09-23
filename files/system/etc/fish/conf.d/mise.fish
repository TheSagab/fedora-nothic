# mise (https://mise.jdx.dev) shell activation for fish.
#
# See /etc/profile.d/mise.sh for the POSIX-shell equivalent.

if command -q mise
    mise activate fish | source
end
