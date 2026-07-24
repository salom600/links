# Lumina Linux

> **Lightweight. Modern. Yours.**
>
> A custom Linux distribution built on Arch Linux, designed for users coming
> from Windows. Features a Windows 11-style desktop with acrylic transparency,
> an integrated app store (Pamac), pre-installed gaming/office/media apps, and
> a guided GUI installer — all in a system that idles at under 100 MB of RAM.

[![Build ISO](https://github.com/salom600/links/actions/workflows/build-iso.yml/badge.svg)](https://github.com/salom600/links/actions/workflows/build-iso.yml)
[![Release](https://img.shields.io/github/v/release/salom600/links?include_prereleases)](https://github.com/salom600/links/releases)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

---

## ✨ Features

| Goal | How Lumina delivers it |
|------|------------------------|
| **≤ 100 MB RAM at idle** | XFCE + picom (no GNOME/KDE bloat), minimal background services, no IndexedDB-style file indexers |
| **Windows 11-style UI** | Fluent GTK theme + Tela Blue icons + Whisker Menu (centered start), Win11 taskbar layout, acrylic blur via picom |
| **Beginner-friendly** | One-click Calamares installer, Pamac app store (AUR + Flatpak + Pacman in one UI), welcome app on first boot |
| **Gaming-ready** | Steam, Proton, Wine, Bottles, ProtonUp-Qt, MangoHud, GameMode preinstalled |
| **Win-migrant helpers** | Super+E = file manager, Super+T = terminal, Super+L = lock screen, os-prober auto-detects Windows in GRUB |
| **CI-built ISO** | Push a `v*.*.*` tag to GitHub and Actions produces a downloadable ISO + GitHub Release automatically |

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Lumina Linux ISO                           │
├──────────────────────────────────────────────────────────────┤
│  Bootloader:  syslinux (BIOS) + systemd-boot (UEFI)          │
│  Kernel:      linux (Arch official, x86_64)                  │
│  Initramfs:   mkinitcpio with archiso hooks                  │
│  Base:        Arch Linux pacstrap + Lumina airootfs overlay  │
│  Display:     Xorg + picom compositor                        │
│  DE:          XFCE 4.20+ with custom Win11 panel layout      │
│  Login:       LightDM GTK Greeter                            │
│  App Store:   Pamac (pacman + AUR + Flatpak)                 │
│  Installer:   Calamares (GUI) with archinstall fallback      │
│  Local repo:  [lumina] — AUR packages built fresh per release│
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository structure

```
links/
├── .github/workflows/build-iso.yml   # Tag-triggered CI pipeline
├── scripts/
│   ├── build-aur-packages.sh         # Builds AUR packages into /tmp/lumina-repo
│   ├── generate-branding-assets.sh   # Creates placeholder PNG/SVG assets
│   └── setup-services.sh             # Creates systemd symlinks in airootfs
├── airootfs/                         # Filesystem overlay (copied onto squashfs)
│   ├── etc/
│   │   ├── hostname                  # "lumina"
│   │   ├── hosts
│   │   ├── pacman.conf               # Enables [lumina] local repo + [multilib]
│   │   ├── mkinitcpio.conf           # Live-ISO initramfs hooks
│   │   ├── lightdm/                  # Login greeter config
│   │   ├── skel/                     # Default $HOME (themes, panel layout, picom, GTK)
│   │   │   └── .config/
│   │   │       ├── picom/picom.conf          # Win11 acrylic blur
│   │   │       ├── gtk-3.0/settings.ini      # Fluent theme
│   │   │       ├── gtk-4.0/settings.ini
│   │   │       └── xfce4/xfconf/xfce-perchannel-xml/
│   │   │           ├── xfce4-panel.xml       # Win11-style taskbar
│   │   │           ├── xfwm4.xml             # Window manager + keybindings
│   │   │           └── xsettings.xml         # GTK theme/icons/fonts
│   │   ├── systemd/system/           # Service enablement (symlinks)
│   │   └── xdg/user-dirs.defaults
│   ├── root/                         # Live-ISO root home
│   └── usr/
│       ├── local/
│       │   ├── bin/
│       │   │   ├── lumina-welcome        # First-boot welcome dialog
│       │   │   ├── lumina-toggle-effects # Toggle transparency on/off
│       │   │   └── lumina-installer      # Calamares wrapper
│       │   ├── repo/lumina/               # Local pacman repo (AUR builds)
│       │   └── share/lumina/scripts/
│       │       └── first-boot.sh          # Post-install customization
│       └── share/
│           ├── applications/              # Custom .desktop entries
│           ├── backgrounds/lumina/        # Wallpapers + logos (generated)
│           ├── calamares/                 # Calamares config + branding
│           └── icons/                     # Custom icons
├── syslinux/                         # BIOS bootloader config
├── efiboot/                          # UEFI systemd-boot config
├── bootloaders/grub/                 # GRUB config (fallback)
├── packages.x86_64                   # Package list for the live ISO
├── profiledef.sh                     # ISO metadata (name, version, modes)
├── pacman.conf                       # Pacman config used by mkarchiso
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## 🚀 Quick start

### Option A — Use a pre-built ISO

1. Go to **[Releases](https://github.com/salom600/links/releases)**
2. Download the latest `lumina-vX.Y.Z-x86_64.iso`
3. Verify the checksum:
   ```bash
   sha256sum -c lumina-vX.Y.Z-x86_64.iso.sha256sum
   ```
4. Write to a USB drive (≥4 GB):
   ```bash
   # Linux
   sudo dd if=lumina-vX.Y.Z-x86_64.iso of=/dev/sdX bs=4M status=progress conv=fsync
   # Replace /dev/sdX with your USB device (use lsblk to identify it)
   ```
   On Windows, use [Rufus](https://rufus.ie/) or [BalenaEtcher](https://etcher.balena.io/).
5. Boot from the USB and click **Install Lumina** on the desktop.

### Option B — Build the ISO yourself

The build runs inside an `archlinux:latest` Docker container, so it works on
any OS with Docker installed.

```bash
# Clone
git clone https://github.com/salom600/links.git
cd links

# Build locally using Docker (no need for Arch Linux on your host)
docker run --rm -it -v "$PWD:/build" -w /build archlinux:latest \
  bash -c '
    pacman -Syu --noconfirm --needed base-devel git archiso grub \
      dosfstools mtools squashfs-tools libisoburn imagemagick &&
    bash scripts/build-aur-packages.sh &&
    bash scripts/generate-branding-assets.sh &&
    bash scripts/setup-services.sh &&
    mkdir -p work out &&
    mkarchiso -v -w work -o out .
  '

# Result: out/lumina-<version>-x86_64.iso
```

### Option C — Let GitHub Actions build it (recommended)

1. Push the repository to `github.com/salom600/links`
2. Tag a release:
   ```bash
   git tag -a v0.1.0 -m "First Lumina Linux release"
   git push origin v0.1.0
   ```
3. Watch the build at `github.com/salom600/links/actions`
4. The ISO appears under `github.com/salom600/links/releases` ~45–75 min later

---

## 🎨 Customization

### Replacing branding assets

The repo ships with auto-generated placeholder PNGs (simple gradients with
the Lumina logo). To use your own designs, replace these files:

| File | Used for | Recommended size |
|------|----------|------------------|
| `airootfs/usr/share/backgrounds/lumina/lumina-logo.png` | Boot logo, menu icon | 512×512 |
| `airootfs/usr/share/backgrounds/lumina/lumina-login.jpg` | LightDM login background | 1920×1080 |
| `airootfs/usr/share/backgrounds/lumina/lumina-grub.png` | GRUB background | 1920×1080 |
| `airootfs/usr/share/calamares/branding/lumina/*.png` | Calamares slideshow | 1200×800 each |

After replacing, commit and tag a new release — the workflow will pick up
your new assets automatically.

### Adding/removing packages

Edit `packages.x86_64`. Each line is one package name (comments start with `#`).

For AUR packages, also add them to the `AUR_PACKAGES` array in
`scripts/build-aur-packages.sh`.

### Changing the theme

- **GTK theme:** edit `airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` → `ThemeName`
- **Icon theme:** same file → `IconThemeName`
- **Panel layout:** `airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`
- **Transparency/blur:** `airootfs/etc/skel/.config/picom/picom.conf`

---

## ⚙️ System requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU       | 64-bit x86_64 (Intel Core 2 Duo / AMD Athlon 64) | Intel Core i3 / AMD Ryzen 3 or newer |
| RAM       | 1.5 GB (live ISO) / 2 GB (installed) | 4 GB |
| Disk      | 20 GB | 50 GB+ (for games, media) |
| GPU       | Any with OpenGL 2.1+ (Intel GMA, AMD R600, NVIDIA Tesla+) | Intel UHD / AMD Vega / NVIDIA GTX 900+ for full acrylic effects |
| Boot mode | BIOS or UEFI | UEFI (recommended) |

---

## 🔐 Security note about GitHub tokens

**Never paste a GitHub Personal Access Token in plaintext** into any file
in this repo, into chat, or into issue/PR descriptions. The workflow uses
the built-in `GITHUB_TOKEN` secret automatically — you do not need to
create or configure any token for the build to work.

If you need to push to a different repo or perform cross-repo operations,
add a Personal Access Token as a **repository secret** (Settings → Secrets
and variables → Actions → New repository secret) and reference it as
`${{ secrets.YOUR_SECRET_NAME }}`.

---

## 🛠️ Troubleshooting

### Build fails in CI with "package not found"

This usually means an AUR package failed to build. Check the workflow log
under the **Build AUR packages** step. The script is designed to skip
optional packages on failure — look for `WARNING:` lines.

To fix:
1. Remove the failing package from `packages.x86_64`
2. Remove it from `AUR_PACKAGES` in `scripts/build-aur-packages.sh`
3. Re-tag and push

### ISO boots but desktop doesn't start

Boot with the **Safe Graphics Mode** option from the boot menu (adds
`nomodeset`). This disables kernel mode setting, which works around most
GPU driver issues.

### Picom effects look choppy

Your GPU may not support the dual_kawase blur method. Run
`lumina-toggle-effects` from the menu to switch to performance mode
(no blur, full framerate).

### Can't see Windows in GRUB after install

Make sure `os-prober` is installed and `GRUB_DISABLE_OS_PROBER=false` is set
in `/etc/default/grub`. The `first-boot.sh` script does this automatically,
but if you skipped it, run:

```bash
sudo pacman -S os-prober
echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 🤝 Contributing

Pull requests welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Test locally with the Docker build command above
4. Open a PR with a clear description of what changed and why

For major changes (new desktop environment, different base distro, etc.),
please open an issue first to discuss.

---

## 📜 License

GPL-3.0 — see [LICENSE](LICENSE).

Lumina Linux is built on top of [Arch Linux](https://archlinux.org/),
which is released under its own licenses. All Arch packages retain their
original licenses.

---

## 🙏 Credits

- **Arch Linux** — the base distribution
- **XFCE** — the desktop environment
- [picom](https://github.com/yshui/picom) — the compositor providing acrylic blur
- [Fluent GTK Theme](https://github.com/vinceliuice/Fluent-gtk-theme) — Win11-style GTK theme by @vinceliuice
- [Tela Icon Theme](https://github.com/vinceliuice/Tela-icon-theme) — Win11-style icons by @vinceliuice
- [Calamares](https://calamares.io/) — the universal installer framework
- [Pamac](https://wiki.manjaro.org/index.php/Pamac) — app store by Manjaro team
- All the package maintainers and AUR contributors whose work makes this possible
