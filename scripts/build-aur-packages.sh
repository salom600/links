#!/usr/bin/env bash
# =============================================================================
# build-aur-packages.sh — Build AUR packages into a local pacman repo
# =============================================================================
# Runs INSIDE the archlinux:latest container during the GitHub Actions build.
#
# Produces: /tmp/lumina-repo/lumina.db.tar.zst + *.pkg.tar.zst
#
# The local repo is referenced by ../pacman.conf via:
#   [lumina]
#   Server = file:///tmp/lumina-repo
#
# Packages that fail to build are logged and skipped — the ISO will still
# be produced, just without that package. This makes the build resilient to
# upstream AUR churn.
# =============================================================================

set -u
set -o pipefail

# ---------- 0. Sanity ----------
if [[ $EUID -eq 0 ]]; then
  echo "This script must NOT be run as root — it uses sudo -u builder."
  echo "Re-invoking under builder..."
  exec sudo -u builder bash "$0" "$@"
fi

# ---------- 1. Configuration ----------
REPO_DIR="/tmp/lumina-repo"
AUR_PACKAGES=(
  # ---------- App store & AUR helper (CRITICAL) ----------
  "paru-bin"                # AUR helper, binary release, fast build
  "pamac-aur"               # App store GUI (supports AUR + Flatpak)

  # ---------- Theming (CRITICAL for Win11 look) ----------
  "fluent-gtk-theme-git"    # Win11-style GTK3/4 theme
  "tela-icon-theme-git"     # Win11-style icon set (blue variant)
  "tela-circle-icon-theme-git"

  # ---------- Win-migrant helpers ----------
  "bottles"                 # Wine prefix manager with GUI
  "protonup-qt"             # Proton-GE version manager

  # ---------- Useful extras ----------
  "nerd-fonts-inter"        # Modern UI font with glyphs
  "grub-theme-vimix"        # GRUB bootloader theme
)

# Packages whose build is allowed to fail without aborting the whole ISO.
# (Keeps the pipeline resilient when upstream AUR deps break.)
OPTIONAL_PACKAGES=(
  "nerd-fonts-inter"
  "grub-theme-vimix"
)

is_optional() {
  local pkg="$1"
  for o in "${OPTIONAL_PACKAGES[@]}"; do
    [[ "$o" == "$pkg" ]] && return 0
  done
  return 1
}

# ---------- 2. Prepare repo dir ----------
echo "==> Preparing local repo at $REPO_DIR"
sudo mkdir -p "$REPO_DIR"
sudo chown -R builder:builder "$REPO_DIR"

# ---------- 3. Pre-install base-devel and pacman-contrib for builder ----------
echo "==> Ensuring build toolchain is installed"
sudo pacman -S --noconfirm --needed --overwrite '*' \
  base-devel git curl wget rsync pacman-contrib

# ---------- 4. Build each AUR package ----------
BUILD_LOG="/tmp/lumina-aur-build.log"
echo "==> AUR build log: $BUILD_LOG"
: > "$BUILD_LOG"

for pkg in "${AUR_PACKAGES[@]}"; do
  echo ""
  echo "=========================================="
  echo "==> Building: $pkg"
  echo "=========================================="

  BUILD_DIR="/tmp/aur-builds/$pkg"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  # Clone AUR repo (shallow)
  if ! git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$BUILD_DIR" 2>&1 | tee -a "$BUILD_LOG"; then
    echo "WARNING: Failed to clone $pkg from AUR" | tee -a "$BUILD_LOG"
    if is_optional "$pkg"; then
      echo "  (optional — continuing)" | tee -a "$BUILD_LOG"
      continue
    else
      echo "  (critical — aborting)" | tee -a "$BUILD_LOG"
      exit 1
    fi
  fi

  # Install build deps listed in .SRCINFO (best-effort)
  # We parse .SRCINFO for depends/makedepends and try to install from official repos.
  if [[ -f .SRCINFO ]]; then
    DEPS=$(grep -E '^\s*(depends|makedepends|checkdepends)\s*=' .SRCINFO \
            | sed -E "s/.*=\s*//" | tr -d "'" | tr ' ' '\n' \
            | grep -v '^$' | sed 's/[>=<].*//' | sort -u)
    if [[ -n "$DEPS" ]]; then
      echo "  -> Installing build deps from official repos..."
      # shellcheck disable=SC2086
      sudo pacman -S --noconfirm --needed --asdeps $DEPS 2>>"$BUILD_LOG" || true
    fi
  fi

  # Build (no install, just produce .pkg.tar.zst)
  if ! makepkg -s --noconfirm --skippgpcheck --noextract 2>&1 | tee -a "$BUILD_LOG"; then
    echo "WARNING: makepkg failed for $pkg" | tee -a "$BUILD_LOG"
    if is_optional "$pkg"; then
      echo "  (optional — continuing)" | tee -a "$BUILD_LOG"
      continue
    else
      echo "  (critical — aborting)" | tee -a "$BUILD_LOG"
      exit 1
    fi
  fi

  # Copy resulting package(s) into the local repo
  cp -v *.pkg.tar.zst "$REPO_DIR/" 2>>"$BUILD_LOG" || true

  # Clean build deps that are no longer needed (orphans)
  sudo pacman -Rns --noconfirm "$(pacman -Qdtq)" 2>/dev/null || true
done

# ---------- 5. Create repo database ----------
echo ""
echo "==> Creating pacman repo database at $REPO_DIR"
cd "$REPO_DIR"
if compgen -G "*.pkg.tar.zst" > /dev/null; then
  repo-add -n -R lumina.db.tar.zst *.pkg.tar.zst
else
  echo "ERROR: No .pkg.tar.zst files were produced. AUR build pipeline failed entirely."
  exit 1
fi

# ---------- 6. Summary ----------
echo ""
echo "=========================================="
echo "==> AUR build summary"
echo "=========================================="
ls -lah "$REPO_DIR/"
echo ""
echo "==> Packages in local repo:"
repo-query() { pacman -Sl lumina 2>/dev/null || true; }
pacman -Sy > /dev/null 2>&1 || true
pacman -Sl lumina 2>/dev/null || echo "(no lumina repo found in pacman db)"
echo ""
echo "==> Done."
