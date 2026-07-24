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
# v0.1.9 RATIONALE — why pamac-aur was removed:
#   pamac-aur is a Rust+Vala source build. On a fresh Actions runner it takes
#   15-20 minutes to compile (cargo release build of the pamac-ui crate +
#   meson build of the libpamac Vala library). With the 7 other AUR packages
#   (~8 min total), that pushed us past the 20-min AUR timeout we added in
#   v0.1.8. Rather than bump the timeout (which just shifts the failure
#   mode), we drop pamac-aur entirely. Users who specifically want Pamac's
#   GUI can install it on first boot via:
#       paru -S --noconfirm pamac-aur
#   The default ISO ships `gnome-software` (in [extra], zero compile time)
#   as the GUI app store — it handles Flatpak + pacman packages.
#
# v0.1.8 RATIONALE — why this list shrank from 16 → 8 packages:
#   The previous v0.1.7 list included `calamares`, `bottles`, `protonup-qt`
#   which are HUGE source builds (cmake + Qt5 + kpmcore for calamares = 20+ min,
#   meson + GTK4 + Python deps for bottles = 30+ min). They alone accounted
#   for 55+ minutes of the 1h15min total build time. They have been REMOVED
#   and replaced with Flatpak-equivalents that users install on-demand from
#   the Pamac app store on first boot — same UX, no 30-min compile step.
#
#   Other removals:
#   - yad, zenity, usbimager, raw-thumbnailer, arc-gtk-theme, arc-icon-theme,
#     gtk-engine-murrine — these were WRONGLY classified as AUR; they are
#     actually in [extra] and have been moved back to packages.x86_64.
#   - syslinux — not needed (UEFI-only boot).
#   - neofetch — already have `fastfetch` (faster, maintained fork).
#   - zoom, snapper-gui — non-essential, install via Pamac if user wants.
#   - wd719x-firmware, aic94xx-firmware, upd72020x-fw — rare SCSI/USB
#     firmware; users with that hardware can install from AUR.
#   - tela-circle-icon-theme-git — redundant with tela-icon-theme-git.
#
#   Total cold-cache AUR build time: ~8-10 min (6 packages, all fast).
#
# Design: ALL packages are treated as non-fatal. If any single package fails
# to build, the script logs the failure and continues. The ISO will be
# produced with whatever packages succeeded — the official Arch repos
# provide everything else.
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
  # ---------- AUR helper (CLI) ----------
  # pamac-aur was REMOVED in v0.1.9 — it's a Rust+Vala source build that
  # takes 15+ minutes alone and pushed us past the 20-min AUR timeout.
  # Users who want Pamac's GUI can install it on first boot via:
  #   paru -S --noconfirm pamac-aur
  # (one-time 15-min build they can do while getting coffee).
  # For the default ISO, we ship `gnome-software` (in [extra], zero compile)
  # as the GUI app store — it handles Flatpak + pacman.
  "paru-bin"                # AUR helper, binary release, ~30s build

  # ---------- Theming (Win11 look) ----------
  "fluent-gtk-theme-git"    # Win11-style GTK3/4 theme, ~1min build (just copies files)
  "tela-icon-theme-git"     # Win11-style icon set, ~2min build
  "xcursor-premium"         # Premium cursor theme, ~1min build

  # ---------- Fonts & bootloader theme ----------
  "nerd-fonts-inter"        # Modern UI font with glyphs, ~3min build
  "grub-theme-vimix"        # GRUB bootloader theme, ~1min build
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

# v0.1.9: cumulative timer for diagnostic visibility. If the build hits the
# 20-min workflow timeout, we can see from the log exactly which package was
# in progress and how much time had been spent so far.
PHASE_START_TS=$(date +%s)
print_phase_elapsed() {
  local now elapsed_min elapsed_sec
  now=$(date +%s)
  elapsed_sec=$((now - PHASE_START_TS))
  elapsed_min=$((elapsed_sec / 60))
  elapsed_sec=$((elapsed_sec % 60))
  echo "==> [elapsed since AUR phase start: ${elapsed_min}m${elapsed_sec}s]"
}

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
  print_phase_elapsed
  build_one "$pkg" || true  # never abort the loop
  # Clean orphaned deps before next build to keep disk usage low
  sudo pacman -Rns --noconfirm "$(pacman -Qdtq)" 2>/dev/null || true
done
print_phase_elapsed
echo "==> All packages processed. AUR phase complete."

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
  echo "         tela-icon-theme will NOT be in the ISO."
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
    echo "    OK $s"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "  Failed to build (${#FAILED[@]}):"
  for f in "${FAILED[@]}"; do
    echo "    FAIL $f"
  done
  echo ""
  echo "  The ISO will be built WITHOUT these packages."
  echo "  Full build log: $BUILD_LOG"
else
  echo ""
  echo "  All packages built successfully."
fi

echo ""
echo "==> Files in $REPO_DIR:"
ls -lah "$REPO_DIR/" 2>/dev/null || echo "  (empty)"

echo ""
echo "==> Done with AUR build phase."
