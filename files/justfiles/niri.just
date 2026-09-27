# Helpers for this image's niri + Noctalia desktop.
#
# The justfiles module imports this file into
# /usr/share/ublue-os/just/60-custom.just, which is what makes these show up
# as `ujust <recipe>` on a Universal Blue based system.

# Print a summary of the image, the desktop stack and the NVIDIA driver state
[group('Desktop')]
niri-info:
    #!/usr/bin/env bash
    set -euo pipefail
    pretty_name=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')
    echo "Image:      ${pretty_name:-unknown}"
    echo "Kernel:     $(uname -r)"
    echo "Compositor: $(niri --version 2>/dev/null || echo 'not installed')"
    echo "Shell:      $(noctalia --version 2>/dev/null || echo 'not installed')"
    echo "Login sh:   $(getent passwd "$USER" | cut -d: -f7)"
    echo "mise:       $(mise --version 2>/dev/null || echo 'not installed')"
    echo
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name,driver_version --format=csv
    else
        echo "No NVIDIA driver on this image (that is the plain fedora-nothic variant)."
    fi
    echo
    echo "Session units:"
    systemctl --user is-enabled pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

# Copy the image's default niri configuration into your home directory
[group('Desktop')]
niri-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
    if [ -e "$dest" ]; then
        echo "$dest already exists."
        echo "Use 'ujust niri-config-reset' to overwrite it with the image default."
        exit 1
    fi
    install -D -m644 /etc/niri/config.kdl "$dest"
    echo "Wrote $dest - niri reloads it as soon as you save."

# Overwrite ~/.config/niri/config.kdl with the image's default configuration
[group('Desktop')]
niri-config-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
    install -D -m644 /etc/niri/config.kdl "$dest"
    echo "Restored $dest from the image default."

# Copy the default Noctalia configuration into your home directory
[group('Desktop')]
noctalia-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml"
    if [ -e "$dest" ]; then
        echo "$dest already exists, leaving it alone."
        exit 0
    fi
    install -D -m644 /etc/skel/.config/noctalia/config.toml "$dest"
    echo "Wrote $dest - Noctalia hot-reloads it."

# Copy the image's ghostty configuration into your home directory
[group('Desktop')]
ghostty-config:
    #!/usr/bin/env bash
    # The image ships this file in /etc/skel, which only reaches accounts created
    # after the image was built. On an account that already existed, ghostty uses
    # whatever the login shell is, so this is how you get the image's config,
    # including `command = /usr/bin/fish`.
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    if [ -e "$dest" ]; then
        echo "$dest already exists."
        echo "Use 'ujust ghostty-config-reset' to overwrite it with the image default."
        exit 1
    fi
    install -D -m644 /etc/skel/.config/ghostty/config "$dest"
    # ghostty's own validator: it exits nonzero and prints the file, line and
    # reason if the config is not usable.
    ghostty +validate-config --config-file="$dest"
    echo "Wrote $dest - ghostty picks it up in new windows."

# Overwrite ~/.config/ghostty/config with the image's default configuration
[group('Desktop')]
ghostty-config-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    install -D -m644 /etc/skel/.config/ghostty/config "$dest"
    ghostty +validate-config --config-file="$dest"
    echo "Restored $dest from the image default."

# Validate the niri configuration and report any errors
[group('Desktop')]
niri-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    niri validate -c /etc/niri/config.kdl
    if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl" ]; then
        echo
        niri validate -c "${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
    fi

# Add your account to the libvirt group so virt-manager can manage VMs
[group('Desktop')]
libvirt-setup:
    #!/usr/bin/env bash
    # The image ships virt-manager and libvirt-daemon-kvm, and Fedora's preset
    # already enables the libvirt sockets, so this membership is the only step
    # left. It takes effect at your next login.
    set -euo pipefail
    if ! getent group libvirt >/dev/null; then
        echo "There is no libvirt group, so libvirt is not installed here." >&2
        echo "Install libvirt-daemon-kvm first." >&2
        exit 1
    fi
    if id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
        echo "$USER is already in the libvirt group."
        exit 0
    fi
    echo "Adding $USER to the libvirt group; usermod needs root."
    sudo usermod -aG libvirt "$USER"
    echo "Done. Log out and back in for it to take effect; 'id -nG' shows your groups."

# Change the login shell of the current user (defaults to fish)
#
# This image sets fish as the shell for accounts created later, and ghostty is
# configured to launch fish regardless of the login shell, so this is only for
# an account whose /etc/passwd entry still says something else.
#
# It goes through usermod, not chsh. Universal Blue deletes /usr/bin/chsh from
# every image built on ublue-os/main, on purpose: changing the login shell on an
# atomic image can lock you out of your account if you later rebase to an image
# that does not carry that shell (ublue-os/main#598). For the same reason this
# refuses a shell that is not listed in /etc/shells, and it checks /etc/shells
# itself, because usermod does not.
#
# Pass a shell to use something else: `ujust set-default-shell /bin/bash`
[group('Desktop')]
set-default-shell shell="/usr/bin/fish":
    #!/usr/bin/env bash
    set -euo pipefail
    # `sudo ujust ...` would otherwise report and change root's shell.
    target_user="${SUDO_USER:-${USER:-$(id -un)}}"
    target="{{ shell }}"
    if [ ! -x "$target" ]; then
        echo "$target is not an executable." >&2
        exit 1
    fi
    if ! grep -qxF "$target" /etc/shells; then
        echo "$target is not listed in /etc/shells, so it is not a usable login shell." >&2
        echo "Available: $(grep -v '^#' /etc/shells | tr '\n' ' ')" >&2
        exit 1
    fi
    current="$(getent passwd "$target_user" | cut -d: -f7)"
    if [ "$current" = "$target" ]; then
        echo "The login shell of $target_user is already $target."
        exit 0
    fi
    case "$target" in
        /usr/*|/bin/*) : ;;
        *)
            echo "warning: $target is outside /usr, so it belongs to your home" >&2
            echo "         directory or to something you installed yourself. If a" >&2
            echo "         future rebase does not provide it, $target_user will not be" >&2
            echo "         able to log in. Only do this if you keep the shell there." >&2
            ;;
    esac
    if [ "$(id -u)" -eq 0 ]; then
        # Running under `sudo ujust ...`, so the shell change is for the
        # invoking user, computed above from SUDO_USER.
        usermod --shell "$target" "$target_user"
    elif command -v sudo >/dev/null 2>&1; then
        echo "Changing a login shell needs root; running usermod through sudo."
        sudo usermod --shell "$target" "$target_user"
    else
        echo "usermod needs root and there is no sudo here." >&2
        echo "Run: usermod --shell $target $target_user" >&2
        exit 1
    fi
    echo "Login shell of $target_user changed from $current to $target."
    echo "It takes effect the next time you log in."
