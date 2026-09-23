# fish configuration for this image.
#
# fish is the default shell here. Two other places matter:
#   /etc/default/useradd   SHELL=/usr/bin/fish, for accounts created later
#   /etc/fish/conf.d/      system-wide snippets, where mise is activated
#
# `ujust set-default-shell` changes the login shell of an existing account.

if status is-interactive
    # No greeting banner on every new shell.
    set -g fish_greeting
end
