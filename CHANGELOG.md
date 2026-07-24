# Changelog

All notable changes to Lumina Linux are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Replace placeholder branding assets with final logo/wallpaper designs
- Add a Lumina Control Center (custom settings GUI)
- Add a Lumina Tour interactive walkthrough
- Pre-configure Flatpak with Flathub + curated app list
- Add ZRAM swap for better low-RAM performance
- Add `linux-zen` kernel variant ISO for gaming-focused users

## [0.1.6] — Fix package list + make AUR cache actually save

### Fixed
- **`packages.x86_64`**: Removed packages that no longer exist in Arch official
  repos and would cause `pacstrap` to abort with "target not found":
  - `syslinux` — removed from Arch in 2025 (now AUR-only; we also dropped the
    `bios.syslinux` boot mode in `profiledef.sh` to match — UEFI-only now)
  - `noto-fonts-compat` — removed from Arch in 2023
  - `xfwm4-themes` — removed from Arch
  - `xcursor-transparent` — never existed in official repos
  - `neofetch` — removed from Arch in 2024 (unmaintained upstream; `fastfetch`
    is the modern replacement and is already in the list)
  - `obs-gstreamer` — never existed as a standalone package
  - `cargo` — virtual package provided by both `rust` and `rustup`. Listing it
    separately caused `pacstrap` to hang on an interactive "choose provider"
    prompt. Since `rust` is already in the list (and provides `cargo`),
    listing `cargo` separately is redundant and was removed.
- **`profiledef.sh`**: Dropped `bios.syslinux` boot mode (now UEFI-only).
  `syslinux` is no longer in Arch official repos, and UEFI has been standard
  on x86_64 hardware since ~2012, so BIOS-only systems are not the target
  audience for a modern Win11-style distro.
- **`.github/workflows/build-iso.yml`**: Added `archlinux-keyring` to the
  initial deps install. The archlinux container's keyring may be stale, which
  can cause pacman to reject packages signed with newer keys (surfacing as
  spurious "target not found" errors during `mkarchiso`'s pacstrap step).

### Added
- **`scripts/build-aur-packages.sh`**: Added 7 new AUR packages that were
  previously in `packages.x86_64` but are AUR-only:
  - `xcursor-premium` — cursor theme
  - `zoom` — video conferencing
  - `snapper-gui` — GUI front-end for snapper
  - `neofetch` — system info (removed from Arch in 2024)
  - `syslinux` — bootloader (removed from Arch in 2025)
  - `wd719x-firmware`, `aic94xx-firmware`, `upd72020x-fw` — rare firmware
- **`.github/workflows/build-iso.yml`**: Switched from implicit `actions/cache@v4`
  (which has both restore and save in a post-step) to EXPLICIT
  `actions/cache/restore` + `actions/cache/save` steps with `if: always()`.
  The implicit post-step is unreliable when a job fails partway through
  inside a container — this is why v0.1.4 saved ZERO caches even though it
  ran for 75 minutes. The new explicit save steps run regardless of job
  success, so a 75-minute AUR build phase will never have to be repeated
  on the next run.
- **`.github/workflows/build-iso.yml`**: Added debug logging step that prints
  cache-hit status and directory contents before and after the AUR build,
  making it easy to diagnose cache issues from the workflow log.

## [0.1.5] — Privileged container + cleanup file_permissions warnings

### Fixed
- **`.github/workflows/build-iso.yml`**: Added `options: --privileged` to the
  archlinux container. Without this, `pacstrap` fails with
  `mount: /__w/.../airootfs/proc: permission denied` because the default
  Actions container doesn't have `CAP_SYS_ADMIN`, which `arch-chroot` needs
  to bind-mount `/proc`, `/sys`, `/dev` into the install root.
  This is the standard approach used by every archiso-on-GHA project.
- **`profiledef.sh`**: Removed `/etc/shadow` and `/etc/gshadow` from
  `file_permissions`. These files are created by pacstrap (via the `filesystem`
  and `shadow` packages) with correct 0400 perms already; listing them in
  `file_permissions` only produced harmless "file does not exist" warnings
  because mkarchiso tried to chmod them *before* pacstrap had created them.

## [0.1.4] — CI caching + airootfs perms fix

### Fixed
- **`profiledef.sh`**: Removed `file_permissions` entries for `/root/.automated_script.sh`
  and `/root/.gnupg` — these files don't exist in our airootfs overlay (they were
  leftover from the archiso sample profile) and caused mkarchiso to abort with
  `Failed to set permissions on '/__w/.../airootfs/root/.automated_script.sh'. Outside of valid path.`
- **`.github/workflows/build-iso.yml`**: Added `pacman-contrib` to the build deps
  so `paccache` is available for cache trimming at the end of the run.

### Added
- **GitHub Actions caching** (cuts warm-cache build time from ~50 min to ~15–25 min):
  - `pacman-v1-${hashFiles('packages.x86_64')}` cache on `/var/cache/pacman/pkg/` —
    on cache hit, `pacman -S` reads directly from the local cache instead of
    re-downloading every package.
  - `aur-repo-v1-${hashFiles('scripts/build-aur-packages.sh')}` cache on
    `/tmp/lumina-repo/` — preserves built AUR `.pkg.tar.zst` files across runs.
- **`scripts/build-aur-packages.sh`**: Added cache-skip logic. If a previously
  built `.pkg.tar.zst` for a package already exists in `/tmp/lumina-repo/`,
  the package is marked `CACHED` and `makepkg` is skipped entirely.
- **Cache-trim step**: `paccache -r -k 1` runs at the end of every build to keep
  only the latest version of each cached package, preventing unbounded growth.

## [0.1.0] — Initial scaffold

### Added
- **Core infrastructure**
  - Archiso-based project structure with `profiledef.sh`, `packages.x86_64`, `pacman.conf`
  - GitHub Actions workflow (`.github/workflows/build-iso.yml`) — tag-triggered (`v*.*.*`), publishes GitHub Release with ISO + SHA256 checksum
  - Local AUR package builder (`scripts/build-aur-packages.sh`) — builds `pamac-aur`, `paru-bin`, `fluent-gtk-theme-git`, `tela-icon-theme-git`, `bottles`, `protonup-qt`, etc. into a local `[lumina]` pacman repo
  - Branding-asset generator (`scripts/generate-branding-assets.sh`) — creates placeholder PNG/SVG logos, wallpapers, and Calamares slideshow images via ImageMagick
  - Systemd service enablement (`scripts/setup-services.sh`) — creates symlinks for NetworkManager, LightDM, Bluetooth, firewalld, TLP, etc.
- **Desktop environment**
  - XFCE 4.x with custom Win11-style panel layout (`xfce4-panel.xml`): Whisker Menu (start), pinned app shortcuts, centered task list, system tray, volume, network, clock
  - xfwm4 configured with Fluent theme, Inter Semi-Bold title font, right-aligned min/max/close buttons, snap-to-edge tiling
  - picom compositor with dual_kawase blur for Win11 acrylic effect, soft shadows, 90% inactive-window opacity, 8px corner rounding
  - Fluent GTK theme + Tela Blue icons + Premium cursor theme
  - LightDM GTK greeter with dark blurred wallpaper and centered login dialog
- **Win-migrant keyboard shortcuts**
  - Super+E → file manager (Thunar)
  - Super+T → terminal
  - Super+L → lock screen
  - Super+I → settings
  - Super+D → show desktop
  - Super+Shift+S → screenshot region
- **Pre-installed apps (general users)**
  - Firefox with uBlock Origin
  - LibreOffice Fresh (full suite, en-US)
  - VLC, MPV
  - Discord, Telegram
  - Thunderbird (email)
  - GNOME Calculator, Screenshot, System Monitor, Disk Utility
  - GIMP, Inkscape (image editing)
  - Evince (PDF), EOG (image viewer)
  - qbittorrent, Transmission
- **Pre-installed gaming stack**
  - Steam, GameMode, MangoHud, Gamescope
  - Wine + Winetricks + vkd3d
  - Bottles (Wine prefix manager) — via AUR
  - ProtonUp-Qt — via AUR
- **App store & package management**
  - Pamac (pacman + AUR + Flatpak unified GUI)
  - paru (AUR helper)
  - Flatpak with Flathub auto-configured on first boot
- **Installer**
  - Calamares with custom Lumina branding, slideshow, and module config (welcome, locale, keyboard, partition, users, mount, unpackfs, fstab, displaymanager, networkcfg, services-systemd, grubcfg, bootloader, packages, finished)
  - `lumina-installer` wrapper script with archinstall fallback
  - First-boot customization script (`first-boot.sh`): copies skel files, adds user to groups, configures Flathub, sets up snapper for btrfs, applies GRUB theme, enables os-prober
- **Bootloaders**
  - syslinux config (BIOS) with Lumina, NVIDIA, and Safe Graphics boot options
  - systemd-boot config (UEFI)
  - GRUB config (fallback)
- **Live-ISO UX**
  - Auto-login as `lumina` user on tty1
  - Welcome app (`lumina-welcome`) shown on first desktop login — install/update/tour buttons
  - Effects toggle (`lumina-toggle-effects`) — switches between full acrylic and performance mode
  - Desktop shortcuts for `Install Lumina` and `Lumina Welcome`

### Known limitations
- Branding assets are auto-generated placeholders (simple gradients with the Lumina "L" logo) — must be replaced before a public release
- The `calamares-branding-lumina` package is not yet packaged as a standalone — branding files are overlaid directly into the airootfs
- Some AUR packages may fail to build intermittently depending on upstream churn — the build script skips them gracefully but the resulting ISO will be missing those packages
- The live ISO uses the `lumina` user with no password; this is intentional for live ISOs but should NOT be carried over to the installed system (Calamares forces a password prompt during install)

[Unreleased]: https://github.com/salom600/links/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/salom600/links/releases/tag/v0.1.0
