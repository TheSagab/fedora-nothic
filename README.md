# fedora-nothic

A personal [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) image, built with
[BlueBuild](https://blue-build.org/) on top of Universal Blue's desktop-less base image.

It is a **niri + Noctalia** desktop instead of GNOME or KDE, with a second
compositor available as an alternative session:

| Piece | What it is | Where it comes from |
| --- | --- | --- |
| [niri](https://github.com/niri-wm/niri) | scrollable-tiling Wayland compositor (the "WM"), and the default session | Fedora repos |
| [Umbriel](https://github.com/noctalia-dev/umbriel) | second compositor, from the Noctalia developers, offered as an extra session | Terra, as `umbriel-nightly` |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | the shell: bar, launcher, notifications, lock screen, wallpaper, control centre, OSDs | Fedora repos (44+) |
| [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter) | the graphical login screen, matched to Noctalia | [Terra](https://terrapkg.com) |
| [ghostty](https://ghostty.org) | terminal - the default one, with `foot` installed alongside | [Terra](https://terrapkg.com) |
| greetd | minimal login manager daemon | Fedora repos |
| [fish](https://fishshell.com) | the default shell | Fedora repos |
| [mise](https://mise.jdx.dev) | polyglot dev tool / runtime version manager | upstream `jdxcode/mise` COPR |

[Terra](https://terrapkg.com) is added as a package repository in its own right,
not just to supply those two packages, so you can install more from it later.

Two images are built from this repository:

| Image | Description |
| --- | --- |
| `ghcr.io/<you>/fedora-nothic` | no GPU driver beyond the in-tree ones |
| `ghcr.io/<you>/fedora-nothic-nvidia` | adds the NVIDIA kernel modules + userspace driver from [ublue-os/akmods](https://github.com/ublue-os/akmods), using the **proprietary** modules |

---

## Repository layout

```
recipes/
  recipe.yml                 # variant A: no NVIDIA driver
  recipe-nvidia.yml          # variant B: NVIDIA driver
  common/                    # modules shared by both variants, run in order
    00-base.yml              # graphics, audio, network, fonts, CLI plumbing
    05-terra.yml             # the Terra package repository
    10-niri.yml              # niri, greetd + noctalia-greeter, portals, XWayland
    15-umbriel.yml           # Umbriel, the second compositor (from Terra)
    20-noctalia.yml          # Noctalia + its runtime dependencies
    30-apps.yml              # terminals, launcher, file manager, media
    40-devtools.yml          # mise + dev CLI tools
    50-files.yml             # copies files/ into the image, installs the justfiles
    60-system.yml            # systemd units, default target, os-release
    90-final.yml             # image signing (must stay last)
  nvidia/
    akmods.yml               # included only by recipe-nvidia.yml
files/
  system/                    # copied verbatim onto / of the image
    etc/niri/config.kdl      # the niri configuration (system default)
    etc/greetd/config.toml   # login manager configuration
    var/lib/noctalia-greeter/greeter.toml  # keeps niri the default session
    etc/default/useradd      # SHELL=/usr/bin/fish for accounts created later
    etc/skel/.config/...     # defaults for newly created users
    usr/lib/tmpfiles.d/      # the greeter's state directory
    usr/lib/sysctl.d/        # inotify limits for dev tooling
  justfiles/niri.just        # ujust recipes (ujust niri-info, niri-config, ...)
disk_config/                 # bootc-image-builder configs for qcow2/ISO output
.github/workflows/
  build.yml                  # builds both images, daily + on push
  build-disk.yml             # manual: qcow2 + installer ISO
```

BlueBuild's `from-file:` paths are relative to `recipes/`, which is why the shared
modules live in `recipes/common/` and are referenced as `common/00-base.yml`.

---

## One-time setup

### 1. Create the repository

Push this directory to a new GitHub repository. The image names in the workflows
are derived from `github.repository_owner`, so no username has to be hard-coded
anywhere - except in the cosmetic `os-release` fields in
`recipes/common/60-system.yml` if you want to change them.

Then open the repository's **Actions** tab once and enable workflows.

### 2. Generate a signing key (required)

BlueBuild signs the images with [cosign](https://docs.sigstore.dev/cosign/overview/),
and the public half is baked into the image so that `bootc switch` / `rpm-ostree
rebase` can verify future updates. **The build fails without it.**

```bash
# install cosign: https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/
./scripts/generate-signing-key.sh
```

or, by hand:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
gh secret set SIGNING_SECRET < cosign.key   # or paste it in Settings -> Secrets -> Actions
```

Run this in the repository directory. It writes `cosign.pub` (public) and
`cosign.key` (private); commit **`cosign.pub`** - the build needs it to install
the verification policy - and never commit `cosign.key`, which is already in
`.gitignore`.

If you prefer not to sign while experimenting, comment out the `signing` module
in `recipes/common/90-final.yml` and use `ostree-unverified-registry:` when
rebasing. Without `cosign.pub` the build stops at the last module with:

```
ERROR: Cannot find 'fedora-nothic.pub' image key in '/etc/pki/containers/'
       BlueBuild CLI should have copied it, but it didn't
```

### 3. Build

Push, or run the `bluebuild` workflow manually. When it is green, both images
exist at:

```
ghcr.io/<you>/fedora-nothic:latest
ghcr.io/<you>/fedora-nothic-nvidia:latest
```

The images are rebuilt daily at 06:00 UTC so they track Fedora, Universal Blue
and Noctalia updates.

---

## Installing

### Option A: rebase an existing Fedora Atomic system

Works from Fedora Atomic, Silverblue, Bazzite, Bluefin, or another BlueBuild image.

```bash
# 1. rebase to the unsigned image first, to pick up the signing policy
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<you>/fedora-nothic:latest
sudo systemctl reboot

# 2. then rebase to the signed image
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/<you>/fedora-nothic:latest
sudo systemctl reboot
```

On a `bootc` based system (Fedora 42+) `sudo bootc switch ghcr.io/<you>/fedora-nothic:latest`
works too - but note that `bootc switch` is what applies kernel arguments, which
matters for the NVIDIA variant.

### Option B: installer ISO

Run the **Build disk images** workflow (`workflow_dispatch`), pick `amd64`, and
download the `fedora-nothic-anaconda-iso` artifact. Flash it with
[Fedora Media Writer](https://fedoraproject.org/workstation/download/) or
`dd`. The same workflow can produce a `qcow2` for VMs.

---

## Using it

Log in at the noctalia-greeter screen, pick the niri session, and Noctalia starts
with the compositor.

The most important key bindings (`Mod` is Super):

| Binding | Action |
| --- | --- |
| `Mod+T` | terminal (ghostty) |
| `Mod+Shift+T` | terminal (foot, the lightweight fallback) |
| `Mod+D`, `Mod+Space` | Noctalia launcher |
| `Mod+S` | Noctalia control centre |
| `Mod+Shift+S` | Noctalia settings |
| `Mod+E` | file manager (Thunar) |
| `Mod+Ctrl+V` | clipboard history (cliphist, picked with fuzzel) |
| `Alt+Tab` | Noctalia window switcher |
| `Mod+O` | niri overview |
| `Super+Alt+L` | lock the screen (Noctalia) |
| `Mod+Shift+Slash` | niri's built-in hotkey overlay |
| `Mod+Shift+E` | leave the session |

`ujust` helpers:

```bash
ujust niri-info          # what is installed, driver state, login shell, units
ujust niri-config        # copy /etc/niri/config.kdl to ~/.config/niri/config.kdl
ujust niri-config-reset  # overwrite your copy with the image default
ujust noctalia-config    # copy the default Noctalia config into your home
ujust niri-validate      # check the niri config for errors
ujust set-default-shell  # change your login shell (defaults to fish)
ujust libvirt-setup      # join the libvirt group so virt-manager can manage VMs
```

What else is on the image, beyond the desktop itself:

* **Everyday**: ghostty and foot, Thunar with its gvfs integrations, imv, mpv,
  file-roller, mousepad, zathura, galculator, calibre, transmission-gtk,
  obs-studio, virt-manager with libvirt-daemon-kvm.
* **Desktop plumbing**: btop and bottom, gdu, pavucontrol, blueman, gammastep,
  cliphist, satty, wf-recorder, guvcview, fwupd, grim and slurp, wl-clipboard,
  fuzzel.
* **Development**: mise, chezmoi, git, gh, neovim, helix, ripgrep, fd-find, bat,
  eza, fzf, git-delta, difftastic, yazi, k9s, gping, duf, tldr, fastfetch,
  starship, atuin, tree, yq, just, podman, buildah.

Two of those need a step before they do anything: `gammastep` is a daemon you
start yourself, and `virt-manager` needs your account in the `libvirt` group
(`ujust libvirt-setup` does it). Both are covered under "Things worth knowing"
below.

### Login screen

**noctalia-greeter** comes from [Terra](https://terrapkg.com). It is a graphical
greeter: greetd runs `/usr/bin/noctalia-greeter-session`, which starts the
wlroots compositor bundled inside the greeter and draws the login screen there.
That is why it needs `wlroots` (Fedora 44 ships 0.20.2, which is what it links
against) and a real logind session - Fedora's greetd package already provides the
latter via `pam_systemd.so` in `/usr/lib/pam.d/greetd-greeter`.

Its settings live in `/var/lib/noctalia-greeter/`: `greeter.toml` for admin
defaults (optional - built-in defaults are used if it is absent) and `sync.toml`,
which the greeter writes to remember your last session and colour scheme. This
image creates that directory owned by the `greetd` user via
`files/system/usr/lib/tmpfiles.d/`. To set defaults, copy the canonical example:
<https://github.com/noctalia-dev/noctalia-greeter/blob/main/examples/greeter.toml>

### Choosing a compositor

The image ships **two** sessions and niri is the default one.

Both compositors install a session file, which is the only thing that puts them
in the greeter's picker: Fedora's niri package ships
`/usr/share/wayland-sessions/niri.desktop`, and Umbriel installs
`/usr/share/wayland-sessions/umbriel.desktop`. The greeter labels them by the
session file's `Name=` field, which is why `noctalia-greeter sessions` prints
`Niri` and `Umbriel` and not the file names.

Which one you get by default is set in
`files/system/var/lib/noctalia-greeter/greeter.toml`, which the image installs
with `[session] default = "Niri"`. Choosing Umbriel once overrides that from then
on, because the greeter remembers your last session in `sync.toml`. To change the
baked-in default, edit that one line - the value is the picker label, so `Niri`
and `Umbriel`.

**Umbriel** is a scrollable/dwindle/master-layout compositor with blur, shadows
and animations, from the same developers as Noctalia, built on wlroots and its
own scene graph. Two things are worth knowing before you pick it:

* It comes from **Terra**, as `umbriel-nightly`: a nightly snapshot
  (`0^20260918git.1a869f9` at the time of writing) rather than a release, because
  upstream publishes no releases or tags. Nothing is pinned in this repository -
  every rebuild takes whatever Terra published most recently - so expect it to
  move under you, and expect the occasional broken night.
* It has **its own configuration format** (live-reloaded TOML), so the niri
  keybindings in this README do not apply to it. The packaged default is
  `/usr/share/umbriel/config.toml` and yours goes in
  `~/.config/umbriel/config.toml`; the documentation is at
  <https://docs.noctalia.dev/umbriel/>. X11 applications work, because
  `xwayland-satellite` is already installed and Umbriel finds it on `PATH`.

Screen capture and screenshot sharing work under Umbriel as well: the package
hard-requires `xdg-desktop-portal-umbriel-nightly`, which ships `umbriel.portal`
and `umbriel-portals.conf`, and xdg-desktop-portal selects that config from the
session's `DesktopNames=Umbriel`. Under niri the same job is done by
`xdg-desktop-portal-gnome`, as before.

### Configuration

**niri** reads `~/.config/niri/config.kdl` and falls back to `/etc/niri/config.kdl`
(the file shipped by this image). Umbriel is configured separately, in TOML; see
"Choosing a compositor" above. `/etc` is writable and survives updates, so you
can edit it in place - but `ujust niri-config` gives you a copy in your home
directory that is easier to keep in dotfiles.

**Noctalia** only reads `~/.config/noctalia/*.toml` plus GUI-managed overrides in
`~/.local/state/noctalia/settings.toml`. New users get a small starting config
from `/etc/skel`; on an existing account run `ujust noctalia-config`, or just use
the Settings window. `noctalia config export > my-config.toml` dumps the merged
config.

**ghostty** reads `~/.config/ghostty/config`; the image ships one in `/etc/skel`
that launches fish and turns off client-side decorations.

**fish** reads `~/.config/fish/config.fish`, with system-wide snippets in
`/etc/fish/conf.d/`.

### Shells

**fish** is the default shell. Three separate things are involved, because a
login shell lives in `/etc/passwd` on the installed system, not in the image:

* `/etc/default/useradd` has `SHELL=/usr/bin/fish`, so accounts created *after*
  installation get fish.
* `ghostty` is configured with `command = /usr/bin/fish`, so the default terminal
  starts fish regardless of what your login shell says.
* For an account that already existed, run `ujust set-default-shell` to change its
  login shell (`ujust set-default-shell /bin/bash` to change it back).

bash and zsh are still installed. **mise** is activated in all three via
`/etc/profile.d/mise.sh` and `/etc/fish/conf.d/mise.fish`. Tools are installed
per user under `~/.local/share/mise`:

```bash
mise use -g node@24
mise use python@3.13     # writes mise.toml in the current project
mise install
```

### NVIDIA variant

The **proprietary** kernel modules (`nvidia-driver: nvidia`) are used by default.
Those cover Maxwell through Ada - GTX 9xx/10xx and RTX 20xx-40xx - and are the
right choice for the cards people actually still run. They do **not** support
Blackwell (RTX 50xx) or newer.

For Blackwell and later, switch to the open modules in
`recipes/nvidia/akmods.yml` - they are the only supported flavour there, and also
work for Turing and newer:

```yaml
nvidia-driver: nvidia-open   # instead of nvidia
```

The module also writes the required kernel arguments
(`rd.driver.blacklist=nouveau`, `modprobe.blacklist=nouveau`,
`nvidia-drm.modeset=1`, `initcall_blacklist=simpledrm_platform_driver_init`)
into `/usr/lib/bootc/kargs.d/`. Those are applied by **bootc**, so if you moved
to this image with `rpm-ostree rebase`, check afterwards with:

```bash
rpm-ostree kargs
# if the nvidia kargs are missing (e.g. `lsmod | grep nvidia` is empty):
sudo rpm-ostree kargs \
  --append-if-missing=rd.driver.blacklist=nouveau \
  --append-if-missing=modprobe.blacklist=nouveau \
  --append-if-missing=nvidia-drm.modeset=1 \
  --append-if-missing=initcall_blacklist=simpledrm_platform_driver_init \
  --delete-if-present=nomodeset
```

If you get a black screen after booting the NVIDIA image on a machine that
should work, try adding `nvidia-drm.fbdev=1` the same way.

---

## What a GNOME or KDE desktop would give you

There is no GNOME or KDE session here: niri is the compositor, Noctalia is the
shell, and greetd is the only display manager. The desktop utilities that come
*with* those sessions are therefore not installed. This is what you would notice
missing, and what to install instead.

The numbers are the **marginal** cost: each package was resolved with `dnf5`
against Fedora 44 (Terra where marked) together with everything else this image
installs, so anything already present costs nothing - `wf-recorder` is one package
because mpv already brings the ffmpeg stack, and `mousepad` was eight because
Thunar already brings GTK and XFCE. The measurements were taken before the
applications now listed as covered were added, when the image's own application
stack came to 204 packages and 244 MiB installed; `install_weak_deps=False`
throughout, as in the recipes.

### Already covered

| You would have used | This image ships |
| --- | --- |
| gnome-terminal, Konsole | ghostty on `Mod+T`, foot on `Mod+Shift+T` |
| Nautilus, Dolphin | Thunar |
| Image viewer (loupe, Gwenview) | imv (no keybinding; it opens from Thunar or the command line) |
| Totem, Dragon | mpv |
| Ark | file-roller, 7zip |
| GNOME Activities, KRunner | Noctalia's launcher on `Mod+D` and `Mod+Space`; fuzzel is installed as a fallback but is not bound to anything |
| GNOME Screenshot, Spectacle | niri's own `screenshot` on `Print`, `Ctrl+Print`, `Alt+Print`, plus grim and slurp for scripts, and Noctalia's UI |
| gnome-shell's clipboard, Klipper | wl-clipboard |
| gnome-keyring, KWallet | gnome-keyring |
| GNOME Settings, System Settings | the niri config and Noctalia's settings |
| GNOME Software, Discover | flatpak, on the command line |
| gnome-shell's password prompts | Noctalia's polkit agent (see below) |
| gedit, Kate (text editor) | mousepad |
| Evince, Okular (PDF) | zathura with the mupdf backend |
| gnome-calculator, KCalc | galculator |
| gnome-system-monitor | btop, and bottom for a second opinion |
| baobab, Filelight (disk usage) | gdu |
| GNOME Night Light | gammastep |
| Klipper (clipboard history) | cliphist, wired to `Mod+Ctrl+V` |
| GNOME Settings, plasma-pa (volume) | pavucontrol |
| Bluedevil | blueman |
| Transmission | transmission-gtk |
| Foliate, Okular (ebooks) | calibre |
| GNOME's screen recorder | obs-studio, plus wf-recorder for a one-liner |
| GNOME Boxes | virt-manager with libvirt-daemon-kvm (run `ujust libvirt-setup` once) |
| Screenshot annotation | satty |
| Cheese, Kamoso (webcam) | guvcview |
| gnome-firmware, Discover (firmware) | fwupd, so `fwupdmgr` works |

### Worth adding, to finish the desktop

| Missing | Install | Marginal cost |
| --- | --- | --- |
| Partitioning (gnome-disks, KDE Partition Manager) | `gparted` | 7, 56 MiB |
| Display arrangement (GNOME Displays, KScreen) | `wdisplays`, or `kanshi`; `wlr-randr` is already here | 1, under 1 MiB |
| Appearance and theming (GNOME Tweaks) | `nwg-look` (Terra) | 1, 4 MiB |
| Network editor (plasma-nm) | `nm-connection-editor` | 10, 25 MiB |
| Colour picker | `gpick`, or `gcolor3` | 1, 1 MiB |
| Printing (GNOME Settings) | `cups` + `system-config-printer` | 36, 80 MiB |
| Scanning (Document Scanner, Skanlite) | `xsane`; `simple-scan` is lighter on disk (7 packages, 4 MiB) | 4, 18 MiB |
| Remote desktop (GNOME Remote Desktop) | `wayvnc` | 3, under 1 MiB |
| Software centre (GNOME Software, Discover) | `dnfdragora` | 8, 18 MiB |
| Password manager (GNOME Passwords, KWallet) | `keepassxc` | 17, 71 MiB |

`wf-recorder` and `guvcview` are as cheap as they are because mpv already brings
the ffmpeg stack, and `mousepad` because Thunar already brings GTK and XFCE.

### Applications you may want

| Missing | Install | Marginal cost |
| --- | --- | --- |
| Mail, calendar, contacts (Evolution, KMail, KOrganizer) | `thunderbird` | 3 packages, 366 MiB |
| Office suite | `libreoffice` | 118, 732 MiB |
| Music (Rhythmbox, Elisa) | `strawberry`, or `audacious` | 22, 68 MiB |
| Image editing | `gimp`, `inkscape` | 51, 236 MiB |
| Video editing (Pitivi, Kdenlive) | `shotcut` | 82, 339 MiB |
| Notes (GNOME Notes, KNotes) | `Zim` | 5, 13 MiB |

### Things worth knowing

**Three of the installed applications need a step that a package cannot do.**

* `virt-manager` and its daemon are both installed, and Fedora's own preset
  (`90-default.preset`) enables `virtqemud.service` with the virtqemud, virtproxyd,
  virtnetworkd and virtnodedevd sockets, so the image needs no `systemctl` line
  for libvirt. The one step that cannot be baked in is the group membership,
  because the account does not exist at build time: run `ujust libvirt-setup`,
  which adds you to the `libvirt` group, and log out and back in. Until then
  virt-manager opens with no connection to offer.
* `gammastep` is a daemon, so installing it changes nothing by itself. Run
  `gammastep -O 4000` for a fixed colour temperature, or `gammastep -c` with a
  location (it can use geoclue) to follow the sun. Nothing starts it for you on
  purpose - a screen that changes colour at login is not something to inflict on
  someone who did not ask for it.
* `cliphist` needs a watcher and a keybinding, both of which the niri config now
  sets up: `spawn-at-startup "wl-paste" "--watch" "cliphist" "store"` and
  `Mod+Ctrl+V`. If you would rather not keep a clipboard history, delete those
  two lines from `files/system/etc/niri/config.kdl` (or from your own copy) and
  the package can go too.

**GNOME applications are not off limits.** They are ordinary GTK applications and
install without the desktop. On the same basis: `nautilus` is 22 packages and
33 MiB, `evince` 35 and 82 MiB, `totem` 34 and 31 MiB, `rhythmbox` 28 and
30 MiB, `gnome-system-monitor` 7 and 15 MiB, `gnome-calculator` 4 and 13 MiB,
`seahorse` 6 and 11 MiB, `gnome-disk-utility` 5 and 8 MiB, `baobab` 1 and 1 MiB -
and not one of them pulls `gnome-shell`, `mutter`, `gdm` or `gnome-session`.
What this image avoids is the *session*, not the toolkit, so if you would rather
have Evince than zathura, install Evince.

**`gparted` is the one real trap.** It needs a polkit authentication agent, and
dnf satisfies that requirement with `gnome-shell` when nothing else provides it.
Measured on this image with Noctalia removed, `gparted` resolves to 325 packages
and 730 MiB, including `gnome-shell`, `mutter`, `gdm` and `gnome-session`;
with Noctalia present - which provides `PolicyKit-authentication-agent` - the
same install is 7 packages and 56 MiB. If you ever build a variant without
Noctalia, add `lxpolkit`, `xfce-polkit`, `mate-polkit`, `lxqt-policykit` or
`polkit-kde` instead. The agent is not optional in any case: it is what makes a
graphical password prompt appear at all, for gparted, for mounting a disk, and
for anything else that asks polkit.

**`virt-manager` pulls two KDE packages.** `kde-filesystem` and
`kf5-filesystem` come in through `xorriso`. They are directory-layout packages, a
few KiB each, not the KDE desktop - `virt-manager` itself is GTK, and its
transaction contains no `plasma`, `kwin` or KF6 libraries.

**The shell tools are wired, and one of the ones asked for does not exist.**

* `starship` and `atuin` do nothing until they are initialised, so the image
  initialises them: `/etc/fish/conf.d/starship.fish` and `atuin.fish` for fish,
  `/etc/profile.d/starship.sh` and `atuin.sh` for bash and zsh, all guarded on
  interactivity so they stay out of scripts. atuin takes Ctrl-R, so fzf's own
  history widget is deliberately left unwired - the note in `atuin.fish` says how
  to swap them.
* `lazygit` comes from Terra, where the package is named
  `golang-github-jesseduffield-lazygit` and provides both `/usr/bin/lazygit` and
  the plain `lazygit` name that the recipe lists. Searching for `lazygit*` misses
  it, which is how it looked absent at first; the version is 0.65.1.
* `neofetch` is in neither Fedora (retired) nor Terra, so `fastfetch` stands in.
  Terra carries `nerdfetch`, which is a different thing.
* `git-delta` and `difftastic` are installed but not configured, because both are
  preferences rather than defaults: delta becomes git's pager with
  `core.pager = delta` and `interactive.diffFilter = delta --color-only`, and
  difftastic with `GIT_EXTERNAL_DIFF=difft`.

### What GNOME is actually in this image

The other half of the question. This is every GNOME or KDE component the image
resolves to, found by resolving the whole package set on an empty root (763
packages) and listing what matches, and what each one is there for.

| Component | What needs it | Can it go? |
| --- | --- | --- |
| `gtk4`, `libadwaita` | ghostty, file-roller and `xdg-desktop-portal-gnome` | Only by dropping all three |
| `gtk4-layer-shell` | ghostty alone | Yes - drop ghostty and keep foot |
| `gnome-desktop3`, `gnome-desktop4` | `xdg-desktop-portal-gnome` | Only by giving up screencast and screen sharing, which niri's own `niri-portals.conf` asks for |
| `gnome-keyring`, `gcr3`, `gcr-libs` | `niri-portals.conf` names it for `org.freedesktop.impl.portal.Secret`, and it is the only package in Fedora 44 that ships a portal file declaring that interface | No |
| `file-roller` | the archive manager in `30-apps.yml`, and what `thunar-archive-plugin` integrates with | Yes, but only to one the plugin has a backend for - it ships `ark.tap`, `engrampa.tap` and file-roller's. `engrampa` is +9 packages here, `ark` +78; `xarchiver` is smaller but the plugin has no backend for it |
| `adwaita-cursor-theme` | chosen in `00-base.yml` | It is a choice, not a requirement; a non-GNOME cursor theme can replace it |
| `adwaita-icon-theme` | required by `gtk3` and `gtk4` | Only with the GTK stack |
| Qt: `qt5-qtbase`, `qt6-qtbase`, `qtdeclarative`, `qtsvg`, `qtwayland` | Noctalia and Quickshell | Not GNOME or KDE, and required for the shell |
| KDE, Plasma, KF5, KF6 | nothing | Already absent |

Two of those "no" answers are worth showing, because they are what niri itself
asks for. `niri-portals.conf` is four lines:

```
[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Access=gtk;
org.freedesktop.impl.portal.Notification=gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
```

and no other packaged backend fills that last role: `xdg-desktop-portal-kde`
ships `kde.portal`, whose `Interfaces=` list does not include
`org.freedesktop.impl.portal.Secret`, and `kwalletd6` ships no portal file at
all. So `gnome-keyring` is not a leftover from a GNOME habit; it is what niri
names.

So there is no KDE at all, and the GNOME content is two libraries, a keyring, a
cursor theme and one application. `file-roller` is the only piece that is a GNOME
*application* rather than a dependency of something else, and the only one that
is genuinely easy to replace.

That replacement was checked rather than assumed: `engrampa` installs on this
image, `thunar-archive-plugin` ships
`/usr/libexec/thunar-archive-plugin/engrampa.tap`, and that wrapper's body is
`exec engrampa --extract-to="$pwd" --extract-here --force "$@"` (and the
equivalent for creating archives). `file-roller`, `engrampa` and `ark` all
install their binary as `/usr/bin/<name>`, so a bare `engrampa` on the wrapper's
PATH resolves, and Thunar's "Extract here" would use it once file-roller is gone.

## Customising

The recipes are deliberately small and commented - edit them directly.

* **Add a package**: put it in the matching `recipes/common/*.yml` under
  `install: packages:`. Note that every module sets `install-weak-deps: false`,
  so `Recommends` are *not* pulled in; if a package needs one, list it too.
* **Change the terminal/launcher**: edit `recipes/common/30-apps.yml` and the
  matching `binds` entries in `files/system/etc/niri/config.kdl`.
* **Different NVIDIA flavour**: see above.
* **Move to the next Fedora release**: bump `image-version` in both recipes,
  check that `noctalia` and `niri` exist for the new release
  (`https://packages.fedoraproject.org/`), and that the `jdxcode/mise` COPR has a
  chroot for it (`https://copr.fedorainfracloud.org/coprs/jdxcode/mise/`).
  Also confirm `ghcr.io/ublue-os/akmods` publishes a `main-<release>` tag, and
  that Terra has a `terra<release>` repository with `noctalia-greeter` and
  `ghostty` in it (<https://repos.fyralabs.com/terra44/repodata/repomd.xml> is
  the pattern to check).
* **A different login screen**: the greeter is noctalia-greeter, configured in
  `files/system/etc/greetd/config.toml`. To go back to a text greeter, install
  `tuigreet` and set
  `command = "tuigreet --time --remember --asterisks --cmd niri-session"`;
  to hand the login screen to SDDM instead, `systemctl disable --now greetd`
  and `systemctl enable --now sddm`.
* **A different file manager**: the file manager is Thunar, with its
  integrations, and that is settled - the alternatives were researched and then
  dropped. The `Mod+E` binding in `files/system/etc/niri/config.kdl` spawns
  `thunar`, which is the binary Fedora's `Thunar` package ships next to
  `/usr/bin/Thunar`. To change it anyway, replace the Thunar block in
  `recipes/common/30-apps.yml` (keep the `gvfs-*` entries - they are what gives
  any file manager trash, MTP, SMB and NFS) and repoint the binding.

### Adding another variant

Copy `recipes/recipe.yml`, change the `name:`, list it in the `matrix.recipe`
of `.github/workflows/build.yml`, and add the image name to
`matrix.image` in `.github/workflows/build-disk.yml` if you want disk images
for it.

---

## Design notes

* **Base image**: `ghcr.io/ublue-os/base-main`, pinned to Fedora 44. It is
  Universal Blue's desktop-less base: codecs, hardware acceleration, distrobox,
  toolbox, `just`/`ujust`, and the ublue signing keys - but no desktop
  environment to strip out.
* **No Quickshell, no Qt/GTK shell**: Noctalia v5 is a native Wayland shell
  written in C++, so there is no Quickshell layer to maintain.
* **Fedora first, then two external repos**: niri, Noctalia, xwayland-satellite,
  greetd, wlroots and fish come from the official Fedora 44 repositories, so they
  are maintained upstream. Two things are not in Fedora: mise (upstream
  `jdxcode/mise` COPR, whose repository file is removed again after the build
  with `cleanup: true`) and noctalia-greeter plus ghostty, which come from
  [Terra](https://terrapkg.com). Terra is left enabled so you can install more
  from it - see `recipes/common/05-terra.yml` for what that means for trust and
  for package priority.
* **Weak dependencies off**: keeps the image deterministic and avoids pulling
  in waybar/alacritty/swaylock that niri recommends but Noctalia replaces.
* **Files go to `/etc`**, not `/usr/etc`: on atomic Fedora the image's `/etc`
  becomes `/usr/etc` at deployment time while `/etc` stays editable locally.
  See <https://blue-build.org/blog/preferring-system-etc/>.

## Troubleshooting

* **No sound**: `systemctl --user status pipewire wireplumber`. The units are
  enabled by the packages' systemd presets; if they are missing, run
  `systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service`.
* **No screen sharing, screen recording or keyring**: niri ships
  `/usr/share/xdg-desktop-portal/niri-portals.conf`, which asks for the `gnome`
  and `gtk` portal backends and for `gnome-keyring` to serve
  `org.freedesktop.impl.portal.Secret`. This image installs
  `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk` and `gnome-keyring`
  (the last one ships
  `/usr/share/xdg-desktop-portal/portals/gnome-keyring.portal`) to satisfy it.
  Check with `systemctl --user status xdg-desktop-portal` and
  `ls /usr/share/xdg-desktop-portal/portals/`.
* **The login screen never appears**: the greeter is a graphical client, so it
  can fail in ways a TUI greeter cannot. Check, in this order:

  ```
  systemctl status greetd
  journalctl -u greetd -b
  ls -l /dev/dri/          # does the greeter have a GPU to render on?
  ```

  greetd is started by `display-manager.service`, which only exists because
  `systemctl set-default graphical.target` was run at build time. If
  `systemctl get-default` says `multi-user.target`, the login screen is
  correctly absent, not broken. If greetd exits immediately with a message about
  a missing session wrapper, the file it names is the one in
  `files/system/etc/greetd/config.toml`.
* **The greeter appears, then the session dies back to it**: that is niri
  starting and failing. `journalctl -b -u greetd` shows the session's output,
  including niri's own errors. The most common cause is a broken
  `/etc/niri/config.kdl`, which `niri validate -c /etc/niri/config.kdl`
  diagnoses.
* **niri starts with an error / ignores the config**: `ujust niri-validate`
  (or `niri validate -c /etc/niri/config.kdl`) prints the parse errors.
* **`bluebuild build` fails in WSL2 with `remount /, flags: 0x44000: invalid argument`**:
  that is the WSL kernel refusing to change root mount propagation, which is what
  container storage does when it applies an image layer. It is not a problem with
  the recipe, and it is not something an isolation mode gets around: a build of
  `FROM scratch` plus a single `COPY` fails the same way under both
  `buildah bud --isolation=chroot` and `--isolation=oci`, and under both the
  `overlay` and `vfs` storage drivers, in the helper that applies the layer
  (`ApplyLayer`). Even pulling a 1 KiB image fails. Build on a real Linux host or
  let GitHub Actions do it.
* **A graphical password prompt never appears** (mounting a disk in Thunar,
  running `gparted`, anything that asks polkit): the polkit *authentication
  agent* is what draws that prompt, and it is part of the desktop shell, not of
  polkit itself. Noctalia provides it, so on this image nothing extra is needed;
  if you build a variant without Noctalia you have to add one - `lxpolkit`,
  `xfce-polkit`, `mate-polkit`, `lxqt-policykit` or `polkit-kde`. Without an
  agent the privileged action simply fails, and dnf may also satisfy the
  requirement with `gnome-shell` if you install something that needs one; see the
  `gparted` note in the section above.
* **The build fails in the Terra modules**: `05-terra.yml` checks that Terra
  offers `ghostty` and `noctalia-greeter`, and stops there with a message if it
  does not, so a repository problem fails early and names itself.

  Terra's repo file does not work unmodified here, for two separate reasons, and
  the image therefore ships its own copy in
  `files/system/etc/yum.repos.d/terra.repo`:

  1. Its `metalink` advertises the checksum of the current repomd.xml while the
     mirrors behind it lag by several metadata revisions (five of the six,
     measured on 2026-09-23), and dnf only tries a couple before giving up:

     ```
     >>> Downloading successful, but checksum doesn't match. Calculated: 477d949d...
         Expected: d64287b0... - https://mirror.freedif.org/.../repomd.xml
     ```

     The repo file points `baseurl` at `repos.fyralabs.com`, which is the origin
     the metalink checksums and so is always current.

  2. Its `repo_gpgcheck=1` fails in a freshly built rootfs with

     ```
     >>> repomd.xml GPG signature verification error: Signing key not found
     ```

     after which dnf treats the repository as offering nothing and you get
     `No match for argument: ghostty`. The signature is not the problem:
     `gpg --verify repomd.xml.asc repomd.xml` against
     `/etc/pki/rpm-gpg/RPM-GPG-KEY-terra44` prints `Good signature from "Terra 44
     <security@fyralabs.com>"`, with the fingerprint that key file declares. It
     is about who imported the key: once a dnf command has imported it itself,
     `repo_gpgcheck=1` starts working, but `rpm --import` alone does not satisfy
     dnf5 5.4.5.0. The repo file sets `repo_gpgcheck=0` rather than depend on
     that ordering. Fedora's own repositories do the same, and `gpgcheck=1` is
     untouched, so every RPM from Terra is still verified against its key.

  If Terra is unreachable the message is `Terra could not be queried. Is
  repos.fyralabs.com reachable?`; if its metadata loads but yields nothing, it is
  `Terra returned no packages at all`. Neither is an image problem. The comments
  at the top of the repo file record all of the measurements above.
* **`ujust` has no `Desktop` group**: the justfiles module appends its imports
  to `/usr/share/ublue-os/just/60-custom.just`; check that the file contains the
  import line for `/usr/share/bluebuild/justfiles/niri.just`.
* **Build fails with "Could not depsolve transaction" in the akmods module**:
  the `kmod-nvidia` RPM requires `kernel-uname-r = <version>`, so it only installs
  when the base image's kernel matches the one the akmods image was built for.
  The error names the requirement, which is the fastest diagnostic:

  ```
  nothing provides kernel-uname-r = 7.2.6-200.fc44.x86_64 needed by kmod-nvidia-3:...
  ```

  Compare that version against `ostree.linux` on
  `ghcr.io/ublue-os/base-main:44` and on the akmods image. This is a transient
  window after a Fedora kernel bump: upstream `ublue-os/akmods` has not caught up
  yet. Wait for their next build and re-run. Note this image never pulls a kernel
  of its own - the resolved package set contains no `kernel*` package, only
  `kmod`/`kmod-libs` - so the base image's kernel is what the kmod must match.

## Assumptions this image makes, and how to change them

Your request left several things open. Rather than guess silently, here is every
choice I made that you might want different, with the exact place to change it.
Nothing below requires touching more than one or two files.

| Assumption | Where it lives | How to change it |
| --- | --- | --- |
| Base is Universal Blue's desktop-less image, pinned to Fedora 44 | `base-image` / `image-version` in both recipes | Bump `image-version`; see "Move to the next Fedora release" under Customising |
| Image names are `fedora-nothic` and `fedora-nothic-nvidia` | `name:` in both recipes, `matrix.recipe` in `build.yml`, `matrix.image` in `build-disk.yml` | Rename in all four places, plus the cosmetic fields in `60-system.yml` |
| Greeter is **noctalia-greeter**, from Terra | `files/system/etc/greetd/config.toml` + the `greetd`/`noctalia-greeter` entries in `10-niri.yml` | Point `command` at `tuigreet` instead (install it first), or at `/usr/bin/niri-session` for autologin-style direct start |
| Terminal is **ghostty**, with `foot` as a fallback on `Mod+Shift+T` | `30-apps.yml` + the `Mod+T` / `Mod+Shift+T` binds in `niri/config.kdl` | Swap the binds, or drop ghostty to save gtk4 |
| There are **two sessions**: niri (the default) and Umbriel | `15-umbriel.yml` installs Terra's `umbriel-nightly`, `files/system/var/lib/noctalia-greeter/greeter.toml` sets the default, and both install a `/usr/share/wayland-sessions/*.desktop` | Change the `default` line in that file, or drop the umbriel module |
| Launcher is Noctalia's built-in one, with `fuzzel` kept as a fallback | the `Mod+D` / `Mod+Space` binds in `niri/config.kdl` | Point those binds at `fuzzel` instead |
| File manager is Thunar, media is mpv, images are imv | `30-apps.yml` | Drop them for Flatpaks if you want a much smaller image; the section above lists what to add for the things a GNOME or KDE desktop would have provided |
| Power profiles come from `power-profiles-daemon` | the `script` snippet in `20-noctalia.yml` | Switch to `tuned-ppd` if you prefer tuned; the snippet already checks for either |
| NVIDIA driver flavour is the **proprietary** `nvidia` | `recipes/nvidia/akmods.yml` | One line: `nvidia-driver: nvidia-open` for Blackwell and newer |
| Terra is added as a package repository and left enabled, with its repo file replaced by one that points `baseurl` at the origin and sets `repo_gpgcheck=0` | `recipes/common/05-terra.yml` + `files/system/etc/yum.repos.d/terra.repo` | Delete the repo file to go back to what Terra ships, or remove the module entirely; see the Terra entry under Troubleshooting |
| **fish** is the default shell | `etc/default/useradd` (new accounts), the ghostty config (terminals), and `ujust set-default-shell` (existing accounts) | See the Shells section above |
| Noctalia ships a small default config (dark, top bar, overview type-to-launch) | `files/system/etc/skel/.config/noctalia/config.toml` | Edit it, or delete it to get pure Noctalia defaults |
| Shell integration for mise covers bash, zsh and fish | `etc/profile.d/mise.sh`, `etc/fish/conf.d/mise.fish` | Add your shell's own activation line if it is not covered |
| Images are signed with your own cosign key | `90-final.yml` + the `SIGNING_SECRET` secret | Comment out the `signing` module to build unsigned while experimenting |

If any of these are wrong for you, say so and I will change them - most are a
one-line edit.

## Re-checking this configuration yourself

The repository was verified against the real Fedora 44 artefacts rather than by
inspection: the real `niri` binary, the real `bluebuild` CLI, every module this
recipe uses executed with its real payload in a Fedora 44 rootfs, and the real
`dnf5` solver. That covers all eight modules of the plain image plus `akmods`
and `initramfs` for the NVIDIA one. On a running system you can repeat most of
it:

```bash
# the niri config parses and passes niri's full schema validation
niri validate -c /etc/niri/config.kdl

# both recipes still satisfy the BlueBuild recipe/module schemas
bluebuild validate recipes/recipe.yml
bluebuild validate recipes/recipe-nvidia.yml

# the greeter: greetd runs the session wrapper, not the plain binary
command -v noctalia-greeter-session
systemctl cat greetd.service | grep -A1 '\[Install\]'

# both sessions are offered, and niri is the one the image defaults to
noctalia-greeter sessions          # expect Niri and Umbriel
grep -A1 '^\[session\]' /var/lib/noctalia-greeter/greeter.toml
umbriel --version                  # the compositor runs, even without a session
rpm -q umbriel-nightly xdg-desktop-portal-umbriel-nightly

# Terra is registered, with this image's repo file in place rather than Terra's
# own, and carries the two packages this image takes from it
grep -c metalink /etc/yum.repos.d/terra.repo      # expect 0
grep -c '^repo_gpgcheck=0' /etc/yum.repos.d/terra.repo   # expect 2
dnf repoquery --repo terra noctalia-greeter ghostty

# Noctalia accepts the shipped config keys
noctalia config validate ~/.config/noctalia/config.toml

# niri's own portal contract is satisfied
cat /usr/share/xdg-desktop-portal/niri-portals.conf
ls /usr/share/xdg-desktop-portal/portals/

# really no GNOME or KDE: niri should be the only compositor and
# greetd the only display manager
systemctl list-units --type=service | grep -E 'gdm|sddm|gnome-shell|plasma'

# the boot path, link by link:
#   default.target -> graphical.target -> display-manager.service -> greetd
systemctl get-default
systemctl show -p Wants --value graphical.target | tr ' ' '\n' | grep display-manager
readlink -f /etc/systemd/system/display-manager.service
systemd-analyze verify /usr/lib/systemd/system/greetd.service

# the user-facing recipes, end to end: this validates the config with the real
# niri binary, and the second one really does change your login shell
ujust niri-validate
ujust set-default-shell /usr/bin/fish

# new accounts default to fish (this only prints the defaults; adding an account
# is what actually exercises it)
useradd -D | grep ^SHELL

# the package set: how heavy it is, and that there is no desktop in it. Feed it
# every package the recipes/common dnf modules name; this is where the numbers
# in the Design notes and in 30-apps.yml come from. Run it on a Fedora 44 host.
dnf5 --installroot=/var/tmp/checkroot --releasever=44 --use-host-config \
  --assumeno install --setopt=install_weak_deps=False <packages>

# the marginal cost of one extra package, which is how the tables under
# "What a GNOME or KDE desktop would give you" were measured: resolve the
# image's own package list on its own (every `install: packages:` entry in
# recipes/common/*.yml), then the same list plus the package you are asking
# about, and subtract. dnf prints the package count and the installed size of
# each transaction; `dnf5 repoquery --latest-limit=1 --queryformat
# '%{installsize}'` gives exact bytes for the same set if you want them.
```

Note that this image has never been built as a container here, so two caveats
apply to that verification: the `akmods` module was driven with a local `skopeo`
stand-in (it performs a real registry pull and writes the same `dir:` layout
`skopeo copy` would), and its SELinux `semodule` step was a no-op because the
build environment had no SELinux. Both are noted because they are the only parts
of the pipeline that were not the real thing.

Two things could be observed but not completed here, and both are the
environment's fault rather than the image's:

* **The skeleton copy that `useradd` does.** `useradd -m` really does give a new
  account `/usr/bin/fish` from the shipped `/etc/default/useradd`, but its copy
  of `/etc/skel` into the new home directory is incomplete in an unprivileged
  user-namespace chroot - it copies only `.bashrc` there, with stock Fedora 44
  files and stock settings, while a plain `cp -r /etc/skel/.` of the same tree
  copies everything. So the fish, ghostty and Noctalia defaults are verified as
  being present in `/etc/skel`, not as arriving in a new home directory.
* **ghostty's own CLI.** `ghostty +validate-config` produces no output at all in
  that chroot, so the shipped ghostty config is checked against the keys
  `Config.zig` declares instead of by running the binary.

Notes that came out of that verification and are easy to trip over:

* The greeter launches `niri-session`, which is exactly the `Exec=` in the
  `niri.desktop` that the Fedora niri package ships in
  `/usr/share/wayland-sessions/`.
* noctalia-greeter must be run through `/usr/bin/noctalia-greeter-session`, not
  as `noctalia-greeter`: the wrapper is what starts its bundled wlroots
  compositor. Its state directory has to be writable by the `greetd` user, which
  is why the image ships a tmpfiles.d entry for it - the uid is allocated
  dynamically at boot, so it cannot be chowned at build time.
* `install-weak-deps: false` really does emit
  `--setopt=install_weak_deps=False`, so niri's `Recommends` (waybar, alacritty,
  swaylock, fuzzel, the portal backends, wireplumber) are not pulled in behind
  your back. Anything you want must be listed explicitly.
* `systemctl enable greetd.service` only creates the `display-manager.service`
  alias - it does **not** add greetd to any target, because the unit's
  `[Install]` section has no `WantedBy`. That is why `recipes/common/60-system.yml`
  explicitly runs `systemctl set-default graphical.target`: `graphical.target`
  wants `display-manager.service`, so the greeter is only reachable through it.
* The `justfiles` module only writes its import into
  `/usr/share/ublue-os/just/60-custom.just` when `/usr/bin/ujust` exists (it does
  on the Universal Blue base, from `ublue-os-just`); otherwise it falls back to
  installing `blujust`.
* Resolving the full package set with `dnf5` against an empty root gives 1134
  packages and ~4 GiB, with **no** `gnome-shell`, `mutter`, `gdm`,
  `gnome-session`, `nautilus`, `plasma*`, `kwin`, `sddm` or `kf5`/`kf6`. The
  only `gnome-*` packages are libraries and a keyring, not a desktop:
  `gnome-desktop3`/`gnome-desktop4` come from `xdg-desktop-portal-gnome` (which
  niri requires for screencast) and `gnome-keyring` is the Secret portal backend
  niri's own `niri-portals.conf` asks for. Note that the image does carry GNOME
  *libraries* that niri and Noctalia alone do not need - `gtk4` and
  `libadwaita` (ghostty hard-requires gtk4, and file-roller and
  xdg-desktop-portal-gnome need both), `gtk4-layer-shell` (ghostty only), and
  `gnome-desktop3`/`gnome-desktop4` (xdg-desktop-portal-gnome). There is still
  no GNOME desktop, and no KDE at all; the section above lists exactly what is
  there and what could be removed.
* For the NVIDIA variant, `ghcr.io/ublue-os/akmods:main-44` and
  `ghcr.io/ublue-os/base-main:44` both report
  `ostree.linux = 7.2.6-200.fc44.x86_64`, i.e. the kmod RPMs are built for the
  exact kernel the base ships. If those ever diverge you get the depsolve error
  mentioned in Troubleshooting - check `rpm-ostree status`/`bootc status` for the
  running kernel and compare with the akmods image tag.

## Links

* BlueBuild docs - <https://blue-build.org/learn/getting-started/>
* BlueBuild recipe reference - <https://blue-build.org/reference/recipe/>
* BlueBuild module reference - <https://blue-build.org/reference/modules/>
* niri configuration - <https://github.com/niri-wm/niri/wiki/Configuration:-Introduction>
* Noctalia docs - <https://docs.noctalia.dev/>
* mise - <https://mise.jdx.dev>
* Universal Blue - <https://universal-blue.org/>
* `ublue-os/image-template` (the non-BlueBuild equivalent of this repo) -
  <https://github.com/ublue-os/image-template>
