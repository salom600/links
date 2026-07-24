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
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ASSETS_DIR="$REPO_ROOT/airootfs/usr/share/backgrounds/lumina"
ICONS_DIR="$REPO_ROOT/airootfs/usr/share/icons"
SYSLINUX_DIR="$REPO_ROOT/syslinux"
CALAMARES_BRANDING="$REPO_ROOT/airootfs/usr/share/calamares/branding/lumina"

mkdir -p "$ASSETS_DIR" "$ICONS_DIR" "$SYSLINUX_DIR" "$CALAMARES_BRANDING"

# Check for ImageMagick
if ! command -v convert >/dev/null 2>&1; then
  echo "WARNING: ImageMagick (convert) not found. Installing..."
  if command -v pacman >/dev/null 2>&1; then
    pacman -S --noconfirm --needed imagemagick
  else
    echo "ERROR: Cannot install ImageMagick automatically on this system."
    echo "       Install ImageMagick manually, then re-run this script."
    exit 1
  fi
fi

# ---------- Lumina color palette (Win11-like) ----------
PRIMARY="#0078D4"      # Win11 blue
ACCENT="#60CDFF"       # light blue
BG_DARK="#1F1F1F"      # dark background
BG_LIGHT="#F3F3F3"     # light background
TEXT_LIGHT="#FFFFFF"
TEXT_DARK="#1F1F1F"

# ---------- Helper: gradient background ----------
make_gradient() {
  local out="$1" w="$2" h="$3" c1="$4" c2="$5"
  convert -size "${w}x${h}" \
          gradient:"${c1}-${c2}" \
          -depth 8 "$out"
}

# ---------- Helper: centered text overlay ----------
add_text() {
  local img="$1" text="$2" size="$3" color="$4"
  convert "$img" -gravity center -fill "$color" \
          -pointsize "$size" -font DejaVu-Sans-Bold \
          -annotate +0+0 "$text" "$img"
}

# ---------- Helper: draw a simple "L" logo ----------
make_logo() {
  local out="$1" size="$2"
  convert -size "${size}x${size}" xc:none \
          -fill "$PRIMARY" -draw "rectangle 0,0 $((size-1)),$((size-1))" \
          -fill "$BG_LIGHT" -draw "rectangle $((size/10)),$((size/10)) $((9*size/10)),$((9*size/10))" \
          -fill "$PRIMARY" -font DejaVu-Sans-Bold -pointsize $((size/2)) \
          -gravity center -annotate +0+0 "L" \
          "$out"
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
convert "$ASSETS_DIR/lumina-login.jpg" \
        \( "$ASSETS_DIR/lumina-logo.png" -resize 200x200 \) \
        -gravity center -geometry +0-100 -composite \
        -gravity center -fill "$TEXT_LIGHT" -pointsize 48 -font DejaVu-Sans-Bold \
        -annotate +0+100 "Lumina Linux" \
        "$ASSETS_DIR/lumina-login.jpg"

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
  cp "$ASSETS_DIR/lumina-${name}.png" "$CALAMARES_BRANDING/"
done

# ---------- Whisker Menu start button icon ----------
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
cp "$ASSETS_DIR/lumina-logo.png" "$CALAMARES_BRANDING/"
cp "$ASSETS_DIR/lumina-welcome.png" "$CALAMARES_BRANDING/"

echo "==> Branding assets generated in $ASSETS_DIR"
echo ""
echo "NOTE: These are PLACEHOLDERS. Replace them with real designs before release."
echo "      See: https://github.com/salom600/links/blob/main/docs/branding.md"
