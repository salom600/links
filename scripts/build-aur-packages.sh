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
# Design: ALL packages are treated as non-fatal. If any single package fails
# to build (due to upstream churn, missing deps, transient network issues,
# etc.), the script logs the failure and continues to the next package.
# The ISO will be produced with whatever packages succeeded — the official
# Arch repos provide everything else.
# =============================================================================

set -u
set -o pipefail

# ---------- 0. Sanity ----------
if [[ $EUID -eq 0 ]]; then
  echo "==> Re-invoking under builder user (makepkg refuses root)..."
  exec sudo -u builder bash "$0" "$@"
fi

# ---------- 1. Configuration ----------
REPO_DIR="/tmp/lumina-repo"
AUR_PACKAGES=(
  # ---------- App store & AUR helper ----------
  "paru-bin"                # AUR helper, binary release, fast build
  "pamac-aur"               # App store GUI (supports AUR + Flatpak)

  # ---------- Theming (Win11 look) ----------
  "fluent-gtk-theme-git"    # Win11-style GTK3/4 theme
  "tela-icon-theme-git"     # Win11-style icon set (blue variant)
  "tela-circle-icon-theme-git"
  "xcursor-premium"         # Premium cursor theme (AUR-only)

  # ---------- Win-migrant helpers ----------
  "bottles"                 # Wine prefix manager with GUI
  "protonup-qt"             # Proton-GE version manager

  # ---------- Useful extras ----------
  "nerd-fonts-inter"        # Modern UI font with glyphs
  "grub-theme-vimix"        # GRUB bootloader theme

  # ---------- Apps that moved out of official Arch repos ----------
  # These were previously in packages.x86_64 but were either removed from
  # Arch official repos or were always AUR-only. Moved here so they end up
  # in the local [lumina] repo and can be installed by pacstrap.
  "neofetch"                # Removed from Arch in 2024 (unmaintained upstream)
  "zoom"                    # Video conferencing (always AUR-only)
  "snapper-gui"             # GUI front-end for snapper (AUR-only)

  # ---------- Bootloader-related (AUR-only since 2025) ----------
  "syslinux"                # Removed from Arch official repos in 2025

  # ---------- Rare firmware (AUR-only) ----------
  "wd719x-firmware"         # Western Digital WD719x SCSI firmware
  "aic94xx-firmware"        # Adaptec AIC94xx SAS controller firmware
  "upd72020x-fw"            # NEC uPD72020x USB 3.0 firmware
)

# Track outcomes for the final summary
declare -a SUCCEEDED=()
declare -a FAILED=()

# ---------- 2. Prepare repo dir ----------
echo "==> Preparing local repo at $REPO_DIR"
sudo mkdir -p "$REPO_DIR"
sudo chown -R builder:builder "$REPO_DIR"

# ---------- 3. Ensure build toolchain ----------
echo "==> Ensuring build toolchain is installed"
sudo pacman -S --noconfirm --needed --overwrite '*' \
  base-devel git curl wget rsync pacman-contrib

# ---------- 4. Build each AUR package ----------
BUILD_LOG="/tmp/lumina-aur-build.log"
echo "==> AUR build log: $BUILD_LOG"
: > "$BUILD_LOG"

build_one() {
  local pkg="$1"
  local start_ts end_ts elapsed
  start_ts=$(date +%s)

  echo ""
  echo "=========================================="
  echo "==> Building: $pkg"
  echo "=========================================="

  # ---------- 4.0. Cache check ----------
  # If a previously-built .pkg.tar.zst for this package already exists in the
  # local repo (restored from the GitHub Actions cache), skip the build entirely.
  # The repo database is regenerated at the end regardless, so cached packages
  # are picked up automatically by mkarchiso's pacstrap.
  local cached_pkg
  cached_pkg=$(ls "$REPO_DIR"/${pkg}-*.pkg.tar.zst 2>/dev/null | head -n1 || true)
  if [[ -n "$cached_pkg" && -f "$cached_pkg" ]]; then
    elapsed=$(( $(date +%s) - start_ts ))
    echo "==> CACHED: $pkg (already in $REPO_DIR, skipping build)"
    echo "    File: $(basename "$cached_pkg")"
    SUCCEEDED+=("$pkg (cached, ${elapsed}s)")
    return 0
  fi

  local BUILD_DIR="/tmp/aur-builds/$pkg"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  # ---------- 4a. Clone AUR repo (shallow) ----------
  if ! git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$BUILD_DIR" 2>&1 | tee -a "$BUILD_LOG"; then
    echo "WARNING: Failed to clone $pkg from AUR" | tee -a "$BUILD_LOG"
    FAILED+=("$pkg (clone failed)")
    return 1
  fi

  # ---------- 4b. Refresh .SRCINFO from PKGBUILD ----------
  # Some AUR repos ship a stale .SRCINFO; regenerate to be safe.
  if [[ -f PKGBUILD ]]; then
    makepkg --printsrcinfo > .SRCINFO 2>>"$BUILD_LOG" || true
  fi

  # ---------- 4c. Install build deps from official repos ----------
  # Parse .SRCINFO for depends/makedepends/checkdepends and install.
  if [[ -f .SRCINFO ]]; then
    local DEPS
    DEPS=$(grep -E '^\s*(depends|makedepends|checkdepends)\s*=' .SRCINFO \
            | sed -E "s/.*=\s*//" \
            | tr -d "'" \
            | tr ' ' '\n' \
            | grep -v '^$' \
            | sed -E 's/[>=<].*//' \
            | sort -u)
    if [[ -n "$DEPS" ]]; then
      echo "  -> Installing build deps from official repos:"
      echo "$DEPS" | sed 's/^/       - /'
      # shellcheck disable=SC2086
      sudo pacman -S --noconfirm --needed --asdeps $DEPS >>"$BUILD_LOG" 2>&1 || true
    fi
  fi

  # ---------- 4d. Build the package ----------
  # Flags explained:
  #   -s           Auto-install missing deps via pacman
  #   --noconfirm  Never prompt
  #   --nocheck    Skip the check() test phase (faster, often fails in CI)
  #   --skipinteg  Skip source integrity checks (AUR sometimes has stale sums)
  # NOTE: Do NOT pass --noextract — that prevents source archives from being
  #       unpacked, which breaks -bin packages whose source IS the prebuilt binary.
  echo "  -> Running makepkg..."
  if makepkg -s --noconfirm --nocheck --skipinteg 2>&1 | tee -a "$BUILD_LOG"; then
    # ---------- 4e. Copy built package(s) into the local repo ----------
    if compgen -G "*.pkg.tar.zst" > /dev/null; then
      cp -v *.pkg.tar.zst "$REPO_DIR/" 2>>"$BUILD_LOG" || true
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      echo "==> OK: $pkg built in ${elapsed}s"
      SUCCEEDED+=("$pkg (${elapsed}s)")
      return 0
    else
      echo "WARNING: makepkg reported success for $pkg but no .pkg.tar.zst was produced" | tee -a "$BUILD_LOG"
      FAILED+=("$pkg (no artifact)")
      return 1
    fi
  else
    echo "WARNING: makepkg failed for $pkg" | tee -a "$BUILD_LOG"
    FAILED+=("$pkg (makepkg failed)")
    return 1
  fi
}

for pkg in "${AUR_PACKAGES[@]}"; do
  build_one "$pkg" || true  # never abort the loop
  # Clean orphaned deps before next build to keep disk usage low
  sudo pacman -Rns --noconfirm "$(pacman -Qdtq)" 2>/dev/null || true
done

# ---------- 5. Create repo database ----------
echo ""
echo "=========================================="
echo "==> Creating pacman repo database at $REPO_DIR"
echo "=========================================="
cd "$REPO_DIR"

if compgen -G "*.pkg.tar.zst" > /dev/null; then
  # Build the local repo database
  repo-add -n -R lumina.db.tar.zst *.pkg.tar.zst
  echo "==> Repo database created."
else
  echo "WARNING: No .pkg.tar.zst files were produced."
  echo "         The ISO will be built WITHOUT any AUR packages — only official"
  echo "         Arch repos will be used. This means pamac, paru, fluent-gtk-theme,"
  echo "         tela-icon-theme, bottles, and protonup-qt will NOT be in the ISO."
  echo "         The build will still succeed; users can install these manually later."
  echo "         (Cache was empty / corrupt on this run — next run will rebuild.)"
fi

# ---------- 6. Summary ----------
echo ""
echo "=========================================="
echo "==> AUR build summary"
echo "=========================================="

if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
  echo ""
  echo "  Successfully built (${#SUCCEEDED[@]}):"
  for s in "${SUCCEEDED[@]}"; do
    echo "    ✅ $s"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "  Failed to build (${#FAILED[@]}):"
  for f in "${FAILED[@]}"; do
    echo "    ❌ $f"
  done
  echo ""
  echo "  The ISO will be built WITHOUT these packages."
  echo "  Full build log: $BUILD_LOG"
else
  echo ""
  echo "  All packages built successfully. 🎉"
fi

echo ""
echo "==> Files in $REPO_DIR:"
ls -lah "$REPO_DIR/" 2>/dev/null || echo "  (empty)"

echo ""
echo "==> Done with AUR build phase."
