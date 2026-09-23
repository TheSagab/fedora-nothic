# sagab-custom-fedora

A personal [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) image, built with
[BlueBuild](https://blue-build.org/) on top of Universal Blue's desktop-less base image.

It is a **niri + Noctalia** desktop instead of GNOME or KDE:

| Piece | What it is | Where it comes from |
| --- | --- | --- |
| [niri](https://github.com/niri-wm/niri) | scrollable-tiling Wayland compositor (the "WM") | Fedora repos |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | the shell: bar, launcher, notifications, lock screen, wallpaper, control centre, OSDs | Fedora repos (44+) |
| [mise](https://mise.jdx.dev) | polyglot dev tool / runtime version manager | upstream `jdxcode/mise` COPR |
| greetd + tuigreet | minimal login manager | Fedora repos |

Two images are built from this repository:

| Image | Description |
| --- | --- |
| `ghcr.io/<you>/sagab-niri` | no GPU driver beyond the in-tree ones |
| `ghcr.io/<you>/sagab-niri-nvidia` | adds the NVIDIA kernel modules + userspace driver from [ublue-os/akmods](https://github.com/ublue-os/akmods) |

---

## Repository layout

```
recipes/
  recipe.yml                 # variant A: no NVIDIA driver
  recipe-nvidia.yml          # variant B: NVIDIA driver
  common/                    # modules shared by both variants, run in order
    00-base.yml              # graphics, audio, network, fonts, CLI plumbing
    10-niri.yml              # niri, greetd, portals, XWayland
    20-noctalia.yml          # Noctalia + its runtime dependencies
    30-apps.yml              # terminal, launcher, file manager, media
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
    etc/skel/.config/...     # defaults for newly created users
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
ERROR: Cannot find 'sagab-niri.pub' image key in '/etc/pki/containers/'
       BlueBuild CLI should have copied it, but it didn't
```

### 3. Build

Push, or run the `bluebuild` workflow manually. When it is green, both images
exist at:

```
ghcr.io/<you>/sagab-niri:latest
ghcr.io/<you>/sagab-niri-nvidia:latest
```

The images are rebuilt daily at 06:00 UTC so they track Fedora, Universal Blue
and Noctalia updates.

---

## Installing

### Option A: rebase an existing Fedora Atomic system

Works from Fedora Atomic, Silverblue, Bazzite, Bluefin, or another BlueBuild image.

```bash
# 1. rebase to the unsigned image first, to pick up the signing policy
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<you>/sagab-niri:latest
sudo systemctl reboot

# 2. then rebase to the signed image
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/<you>/sagab-niri:latest
sudo systemctl reboot
```

On a `bootc` based system (Fedora 42+) `sudo bootc switch ghcr.io/<you>/sagab-niri:latest`
works too - but note that `bootc switch` is what applies kernel arguments, which
matters for the NVIDIA variant.

### Option B: installer ISO

Run the **Build disk images** workflow (`workflow_dispatch`), pick `amd64`, and
download the `sagab-niri-anaconda-iso` artifact. Flash it with
[Fedora Media Writer](https://fedoraproject.org/workstation/download/) or
`dd`. The same workflow can produce a `qcow2` for VMs.

---

## Using it

Log in with greetd/tuigreet, pick the niri session, and Noctalia starts with the
compositor.

The most important key bindings (`Mod` is Super):

| Binding | Action |
| --- | --- |
| `Mod+T` | terminal (foot) |
| `Mod+D`, `Mod+Space` | Noctalia launcher |
| `Mod+S` | Noctalia control centre |
| `Mod+Shift+S` | Noctalia settings |
| `Mod+E` | file manager (Thunar) |
| `Alt+Tab` | Noctalia window switcher |
| `Mod+O` | niri overview |
| `Super+Alt+L` | lock the screen (Noctalia) |
| `Mod+Shift+Slash` | niri's built-in hotkey overlay |
| `Mod+Shift+E` | leave the session |

`ujust` helpers:

```bash
ujust niri-info          # what is installed, driver state, session units
ujust niri-config        # copy /etc/niri/config.kdl to ~/.config/niri/config.kdl
ujust niri-config-reset  # overwrite your copy with the image default
ujust noctalia-config    # copy the default Noctalia config into your home
ujust niri-validate      # check the niri config for errors
```

### Configuration

**niri** reads `~/.config/niri/config.kdl` and falls back to `/etc/niri/config.kdl`
(the file shipped by this image). `/etc` is writable and survives updates, so you
can edit it in place - but `ujust niri-config` gives you a copy in your home
directory that is easier to keep in dotfiles.

**Noctalia** only reads `~/.config/noctalia/*.toml` plus GUI-managed overrides in
`~/.local/state/noctalia/settings.toml`. New users get a small starting config
from `/etc/skel`; on an existing account run `ujust noctalia-config`, or just use
the Settings window. `noctalia config export > my-config.toml` dumps the merged
config.

**mise** is activated in bash, zsh and fish via `/etc/profile.d/mise.sh` and
`/etc/fish/conf.d/mise.fish`. Tools are installed per user under
`~/.local/share/mise`:

```bash
mise use -g node@24
mise use python@3.13     # writes mise.toml in the current project
mise install
```

### NVIDIA variant

The `nvidia-open` kernel modules are used by default, which covers Turing
(GTX 16xx / RTX 20xx) and newer, and is required for Blackwell (RTX 50xx).

For Maxwell, Pascal or Volta (GTX 9xx/10xx, some RTX 20xx), switch to the
proprietary modules by editing `recipes/nvidia/akmods.yml`:

```yaml
nvidia-driver: nvidia   # instead of nvidia-open
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
  Also confirm `ghcr.io/ublue-os/akmods` publishes a `main-<release>` tag.
* **A graphical login screen**: replace tuigreet in
  `files/system/etc/greetd/config.toml` with `gtkgreet` (plus `cage` and
  `gtk4-layer-shell`), or drop greetd for SDDM.

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
* **Fedora packages over COPRs**: niri, Noctalia, xwayland-satellite, greetd,
  tuigreet and everything else except mise come from the official Fedora 44
  repositories, so they are maintained upstream. The only COPR is mise's, and
  its repository file is removed again after the build (`cleanup: true`).
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
* **niri starts with an error / ignores the config**: `ujust niri-validate`
  (or `niri validate -c /etc/niri/config.kdl`) prints the parse errors.
* **`bluebuild build` fails in WSL2 with `remount /, flags: 0x44000: invalid argument`**:
  that is the WSL kernel refusing to change root mount propagation, which is what
  container storage does when it applies an image layer. It is not a problem with
  the recipe - even pulling a 1 KiB image fails the same way, under both the
  `overlay` and `vfs` storage drivers. Build on a real Linux host or let GitHub
  Actions do it.
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
| Image names are `sagab-niri` and `sagab-niri-nvidia` | `name:` in both recipes, `matrix.recipe` in `build.yml`, `matrix.image` in `build-disk.yml` | Rename in all four places, plus the cosmetic fields in `60-system.yml` |
| Greeter is the **TUI** greeter tuigreet | `files/system/etc/greetd/config.toml` + the `greetd`/`tuigreet` entries in `10-niri.yml` | Swap `command` for `gtkgreet` (add `gtkgreet cage gtk4-layer-shell`), or replace greetd with SDDM |
| Terminal is `foot` | `30-apps.yml` + the `Mod+T` bind in `niri/config.kdl` | Change both; `alacritty` is what niri's own defaults use |
| Launcher is Noctalia's built-in one, with `fuzzel` kept as a fallback | the `Mod+D` / `Mod+Space` binds in `niri/config.kdl` | Point those binds at `fuzzel` instead |
| File manager is Thunar, media is mpv, images are imv | `30-apps.yml` | Drop them for Flatpaks if you want a much smaller image (see the weight note in that file) |
| Power profiles come from `power-profiles-daemon` | the `script` snippet in `20-noctalia.yml` | Switch to `tuned-ppd` if you prefer tuned; the snippet already checks for either |
| NVIDIA driver flavour is `nvidia-open` | `recipes/nvidia/akmods.yml` | One line: `nvidia-driver: nvidia` for Maxwell..Ada |
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

# greetd's greeter flags exist in the packaged tuigreet
tuigreet --help | grep -E '\-\-cmd|\-\-greeting|\-\-remember|\-\-asterisks|\-\-time'

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
```

Note that this image has never been built as a container here, so two caveats
apply to that verification: the `akmods` module was driven with a local `skopeo`
stand-in (it performs a real registry pull and writes the same `dir:` layout
`skopeo copy` would), and its SELinux `semodule` step was a no-op because the
build environment had no SELinux. Both are noted because they are the only parts
of the pipeline that were not the real thing.

Notes that came out of that verification and are easy to trip over:

* The greeter launches `niri-session`, which is exactly the `Exec=` in the
  `niri.desktop` that the Fedora niri package ships in
  `/usr/share/wayland-sessions/`.
* `--remember`/`--remember-session` need the greeter's state directory to be
  writable. Fedora patches tuigreet to write to `/var/lib/greetd/` and its
  greetd package creates that directory with the right ownership, so nothing
  extra is needed - on the *upstream* build it would be `/var/cache/tuigreet`
  and you would have to create it yourself.
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
* Resolving the full package set with `dnf5` on a minimal Fedora 44 base gives
  639 packages with **no** `gnome-shell`, `mutter`, `gdm`, `gnome-session`,
  `nautilus`, `plasma*`, `kwin`, `sddm` or `kf5`/`kf6`. The only `gnome-*`
  packages are libraries and a keyring, not a desktop: `gnome-desktop3`/
  `gnome-desktop4` come from `xdg-desktop-portal-gnome` (which niri requires for
  screencast) and `gnome-keyring` is the Secret portal backend niri's own
  `niri-portals.conf` asks for.
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
