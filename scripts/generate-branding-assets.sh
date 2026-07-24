#!/usr/bin/env bash
# =============================================================================
# generate-branding-assets.sh — Create placeholder PNG/SVG branding assets
# =============================================================================
# Runs INSIDE the GitHub Actions container (archlinux:latest has ImageMagick).
# Also runnable locally on any Linux with ImageMagick installed.
#
# Generates:
#   - airootfs/usr/share/backgrounds/lumina/lumina-logo.png       (512x512)
#   - airootfs/usr/share/backgrounds/lumina/lumina-user.png       (128x128)
#   - airootfs/usr/share/backgrounds/lumina/lumina-login.jpg      (1920x1080)
#   - airootfs/usr/share/backgrounds/lumina/lumina-grub.png      (1920x1080)
#   - airootfs/usr/share/backgrounds/lumina/lumina-welcome.png   (1200x800)
#   - airootfs/usr/share/backgrounds/lumina/lumina-appstore.png  (1200x800)
#   - airootfs/usr/share/backgrounds/lumina/lumina-taskbar.png   (1200x800)
#   - airootfs/usr/share/backgrounds/lumina/lumina-gaming.png    (1200x800)
#   - airootfs/usr/share/backgrounds/lumina/lumina-installing.png (1200x800)
#   - airootfs/usr/share/icons/lumina-start-symbolic.svg         (48x48)
#   - syslinux/splash.png                                         (640x400)
#
# These are PLACEHOLDERS — replace them with real designs before release.
#
# RESILIENCE: This script NEVER fails the build. If ImageMagick or a font
# is missing, it falls back to plain-colored images or skips text overlays.
# Branding is cosmetic — the ISO should still build even if every asset
# fails to generate.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ASSETS_DIR="$REPO_ROOT/airootfs/usr/share/backgrounds/lumina"
ICONS_DIR="$REPO_ROOT/airootfs/usr/share/icons"
SYSLINUX_DIR="$REPO_ROOT/syslinux"
CALAMARES_BRANDING="$REPO_ROOT/airootfs/usr/share/calamares/branding/lumina"

mkdir -p "$ASSETS_DIR" "$ICONS_DIR" "$SYSLINUX_DIR" "$CALAMARES_BRANDING"

# ---------- Locate the ImageMagick binary (prefer 'magick' in IMv7) ----------
if command -v magick >/dev/null 2>&1; then
  IM="magick"
elif command -v convert >/dev/null 2>&1; then
  IM="convert"
else
  echo "==> ImageMagick not found. Installing..."
  if command -v pacman >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then
      pacman -S --noconfirm --needed imagemagick ttf-dejavu || true
    else
      sudo pacman -S --noconfirm --needed imagemagick ttf-dejavu || true
    fi
  else
    echo "WARNING: Cannot install ImageMagick on this system. Skipping branding generation."
    echo "         The ISO will still build, just without logos/wallpapers."
    # Create empty placeholder files so mkarchiso doesn't fail when copying
    for f in lumina-logo.png lumina-user.png lumina-grub.png lumina-welcome.png \
             lumina-appstore.png lumina-taskbar.png lumina-gaming.png lumina-installing.png; do
      : > "$ASSETS_DIR/$f"
    done
    exit 0
  fi
  # Re-detect
  if command -v magick >/dev/null 2>&1; then IM="magick"; elif command -v convert >/dev/null 2>&1; then IM="convert"; else IM=""; fi
fi

if [[ -z "$IM" ]]; then
  echo "WARNING: ImageMagick install failed. Skipping branding generation."
  for f in lumina-logo.png lumina-user.png lumina-grub.png lumina-welcome.png \
           lumina-appstore.png lumina-taskbar.png lumina-gaming.png lumina-installing.png; do
    : > "$ASSETS_DIR/$f"
  done
  exit 0
fi

echo "==> Using ImageMagick binary: $IM"

# ---------- Locate a usable font (prefer full path over font name) ----------
FONT=""
FONT_CANDIDATES=(
  "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
  "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
  "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"
  "/usr/share/fonts/TTF/DejaVuSans.ttf"
)
for f in "${FONT_CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    FONT="$f"
    break
  fi
done

# If no DejaVu found, try to install it (best-effort)
if [[ -z "$FONT" ]] && command -v pacman >/dev/null 2>&1; then
  echo "  -> Installing ttf-dejavu font..."
  if [[ $EUID -eq 0 ]]; then
    pacman -S --noconfirm --needed ttf-dejavu 2>/dev/null || true
  else
    sudo pacman -S --noconfirm --needed ttf-dejavu 2>/dev/null || true
  fi
  for f in "${FONT_CANDIDATES[@]}"; do
    [[ -f "$f" ]] && FONT="$f" && break
  done
fi

if [[ -n "$FONT" ]]; then
  echo "  -> Using font: $FONT"
else
  echo "  -> WARNING: No TrueType font available. Text overlays will be skipped."
  echo "             (Install ttf-dejavu or any TTF font to enable text overlays.)"
fi

# ---------- Lumina color palette (Win11-like) ----------
PRIMARY="#0078D4"      # Win11 blue
ACCENT="#60CDFF"       # light blue
BG_DARK="#1F1F1F"      # dark background
BG_LIGHT="#F3F3F3"     # light background
TEXT_LIGHT="#FFFFFF"
TEXT_DARK="#1F1F1F"

# ---------- Helper: gradient background (non-fatal) ----------
make_gradient() {
  local out="$1" w="$2" h="$3" c1="$4" c2="$5"
  $IM -size "${w}x${h}" gradient:"${c1}-${c2}" -depth 8 "$out" 2>/dev/null
  # If gradient failed (some IM builds can't parse gradient:), use solid color
  if [[ ! -s "$out" ]]; then
    $IM -size "${w}x${h}" "xc:${c1}" "$out" 2>/dev/null || true
  fi
}

# ---------- Helper: centered text overlay (non-fatal) ----------
add_text() {
  local img="$1" text="$2" size="$3" color="$4"
  [[ -z "$FONT" ]] && return 0   # no font available — skip text
  # Use -font with full path (more reliable than font name)
  $IM "$img" -gravity center -fill "$color" \
      -pointsize "$size" -font "$FONT" \
      -annotate +0+0 "$text" "$img" 2>/dev/null || true
  # If text failed, the image is still intact (just without text)
}

# ---------- Helper: draw a simple "L" logo (non-fatal) ----------
make_logo() {
  local out="$1" size="$2"
  # Use solid-color rectangles — no text needed for the logo
  $IM -size "${size}x${size}" xc:none \
      -fill "$PRIMARY" -draw "rectangle 0,0 $((size-1)),$((size-1))" \
      -fill "$BG_LIGHT" -draw "rectangle $((size/10)),$((size/10)) $((9*size/10)),$((9*size/10))" \
      "$out" 2>/dev/null

  # If that failed, just make a solid blue square
  if [[ ! -s "$out" ]]; then
    $IM -size "${size}x${size}" "xc:${PRIMARY}" "$out" 2>/dev/null || \
      : > "$out"  # last resort: empty file (mkarchiso will skip it)
    return 0
  fi

  # Try to draw an "L" letter in the center (best-effort, non-fatal)
  if [[ -n "$FONT" ]]; then
    $IM "$out" -fill "$PRIMARY" -font "$FONT" -pointsize $((size/2)) \
        -gravity center -annotate +0+0 "L" "$out" 2>/dev/null || true
  fi
}

echo "==> Generating Lumina branding assets..."

# ---------- Logo (used in many places) ----------
echo "  - lumina-logo.png (512x512)"
make_logo "$ASSETS_DIR/lumina-logo.png" 512

# ---------- User avatar ----------
echo "  - lumina-user.png (128x128)"
make_logo "$ASSETS_DIR/lumina-user.png" 128

# ---------- Login background (dark gradient with logo) ----------
echo "  - lumina-login.jpg (1920x1080)"
make_gradient "$ASSETS_DIR/lumina-login.jpg" 1920 1080 "$BG_DARK" "#0078D4"
# Overlay logo + text (best-effort)
if [[ -s "$ASSETS_DIR/lumina-login.jpg" ]] && [[ -s "$ASSETS_DIR/lumina-logo.png" ]]; then
  $IM "$ASSETS_DIR/lumina-login.jpg" \
      \( "$ASSETS_DIR/lumina-logo.png" -resize 200x200 \) \
      -gravity center -geometry +0-100 -composite \
      "$ASSETS_DIR/lumina-login.jpg" 2>/dev/null || true
fi
add_text "$ASSETS_DIR/lumina-login.jpg" "Lumina Linux" 48 "$TEXT_LIGHT"

# ---------- GRUB background ----------
echo "  - lumina-grub.png (1920x1080)"
make_gradient "$ASSETS_DIR/lumina-grub.png" 1920 1080 "$BG_DARK" "#005A9E"

# ---------- Calamares slideshow images ----------
for name in welcome appstore taskbar gaming installing; do
  echo "  - lumina-${name}.png (1200x800)"
  make_gradient "$ASSETS_DIR/lumina-${name}.png" 1200 800 "$BG_DARK" "$PRIMARY"
  case "$name" in
    welcome)    TEXT="Welcome to Lumina Linux" ;;
    appstore)   TEXT="App Store Built-In" ;;
    taskbar)    TEXT="Win11-Style Taskbar" ;;
    gaming)     TEXT="Ready to Game" ;;
    installing) TEXT="Installing..." ;;
  esac
  add_text "$ASSETS_DIR/lumina-${name}.png" "$TEXT" 48 "$TEXT_LIGHT"
  # Copy into Calamares branding dir too
  cp -f "$ASSETS_DIR/lumina-${name}.png" "$CALAMARES_BRANDING/" 2>/dev/null || true
done

# ---------- Whisker Menu start button icon (SVG, no IM needed) ----------
echo "  - lumina-start-symbolic.svg (48x48)"
cat > "$ICONS_DIR/lumina-start-symbolic.svg" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <rect x="6" y="6" width="14" height="14" rx="1" fill="#0078D4"/>
  <rect x="28" y="6" width="14" height="14" rx="1" fill="#0078D4"/>
  <rect x="6" y="28" width="14" height="14" rx="1" fill="#0078D4"/>
  <rect x="28" y="28" width="14" height="14" rx="1" fill="#0078D4"/>
</svg>
EOF

# ---------- Syslinux splash ----------
echo "  - splash.png (640x400)"
make_gradient "$SYSLINUX_DIR/splash.png" 640 400 "$BG_DARK" "#005A9E"
add_text "$SYSLINUX_DIR/splash.png" "Lumina Linux" 32 "$TEXT_LIGHT"

# ---------- Copy logo into Calamares branding dir ----------
cp -f "$ASSETS_DIR/lumina-logo.png" "$CALAMARES_BRANDING/" 2>/dev/null || true
cp -f "$ASSETS_DIR/lumina-welcome.png" "$CALAMARES_BRANDING/" 2>/dev/null || true

# ---------- Summary ----------
echo ""
echo "=============================================="
echo "==> Branding asset summary"
echo "=============================================="
for f in "$ASSETS_DIR"/*.png "$ASSETS_DIR"/*.jpg "$ICONS_DIR"/lumina-start-symbolic.svg "$SYSLINUX_DIR"/splash.png "$CALAMARES_BRANDING"/*.png; do
  if [[ -f "$f" ]]; then
    size=$(stat -c %s "$f" 2>/dev/null || echo "?")
    if [[ "$size" == "0" ]]; then
      echo "  ⚠️  EMPTY: $f (ImageMagick failed for this file)"
    else
      echo "  ✅ $(basename "$f") — ${size} bytes"
    fi
  fi
done

echo ""
echo "==> Branding generation complete."
echo "NOTE: These are PLACEHOLDERS. Replace them with real designs before release."
echo "      See: https://github.com/salom600/links/blob/main/docs/branding.md"

# Always exit 0 — branding is cosmetic, never block the ISO build
exit 0
