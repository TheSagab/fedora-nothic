# Helpers for Umbriel, the second compositor this image ships next to niri.
#
# Imported into /usr/share/ublue-os/just/60-custom.just by the justfiles
# module, so these show up as `ujust <recipe>`.

# Copy the image's default Umbriel configuration into your home directory
[group('Desktop')]
umbriel-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/config.toml"
    if [ -e "$dest" ]; then
        echo "$dest already exists."
        echo "Use 'ujust umbriel-config-reset' to overwrite it with the image default."
        exit 1
    fi
    # The image default is found through XDG_CONFIG_DIRS. Copying it is only
    # needed to edit it: the file includes /usr/share/umbriel/config.toml, so
    # a copy is self-contained.
    install -D -m644 /etc/xdg/umbriel/config.toml "$dest"
    echo "Wrote $dest - Umbriel reloads it as soon as you save."

# Overwrite ~/.config/umbriel/config.toml with the image's default configuration
[group('Desktop')]
umbriel-config-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/config.toml"
    install -D -m644 /etc/xdg/umbriel/config.toml "$dest"
    echo "Restored $dest from the image default."

# Validate the Umbriel configuration and report any errors
[group('Desktop')]
umbriel-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    umbriel validate -c /etc/xdg/umbriel/config.toml
    user_config="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/config.toml"
    if [ -e "$user_config" ]; then
        echo
        umbriel validate -c "$user_config"
    fi
