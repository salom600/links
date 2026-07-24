#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Helper to push the Lumina Linux project to GitHub
# =============================================================================
# Usage:
#   ./deploy.sh
#
# This script will:
#   1. Initialize git if needed
#   2. Add all files (respecting .gitignore)
#   3. Commit with a sensible default message
#   4. Ask for your GitHub repo URL
#   5. Push to main
#   6. Optionally tag v0.1.0 and push the tag to trigger the build
# =============================================================================

set -euo pipefail

REPO_URL_DEFAULT="https://github.com/salom600/links.git"

echo "=============================================="
echo "  Lumina Linux — GitHub Deploy Helper"
echo "=============================================="
echo ""

# ---------- 1. Initialize git if needed ----------
if [[ ! -d .git ]]; then
  echo "==> Initializing git repository..."
  git init -b main
fi

# ---------- 2. Stage and commit ----------
echo "==> Staging files..."
git add .

if git diff --cached --quiet; then
  echo "==> No changes to commit."
else
  echo "==> Committing..."
  git commit -m "feat: Lumina Linux v0.1.0 — initial scaffold

- Archiso-based project structure with profiledef.sh, packages.x86_64, pacman.conf
- GitHub Actions workflow (tag-triggered, publishes GitHub Release with ISO)
- Local AUR package builder (pamac-aur, paru-bin, fluent-gtk-theme-git, etc.)
- Branding-asset generator (placeholder PNGs/SVGs via ImageMagick)
- XFCE desktop with Win11-style panel layout (Whisker Menu, centered taskbar)
- picom compositor with dual_kawase blur for acrylic effect
- Fluent GTK theme + Tela Blue icons + Premium cursor
- LightDM GTK greeter with dark blurred wallpaper
- Calamares installer with custom Lumina branding
- Pre-installed apps: Firefox, LibreOffice, VLC, Discord, Steam, Wine, Bottles
- Win-migrant shortcuts: Super+E/T/L/D/I, os-prober for dual-boot with Windows
- lumina-welcome first-boot dialog + lumina-toggle-effects performance toggle
"
fi

# ---------- 3. Configure remote ----------
echo ""
echo "==> Configuring remote..."
if git remote get-url origin >/dev/null 2>&1; then
  echo "  Origin already set: $(git remote get-url origin)"
else
  read -rp "Enter your GitHub repo URL [$REPO_URL_DEFAULT]: " REPO_URL
  REPO_URL="${REPO_URL:-$REPO_URL_DEFAULT}"
  git remote add origin "$REPO_URL"
  echo "  Origin set to: $REPO_URL"
fi

# ---------- 4. Push to main ----------
echo ""
echo "==> Pushing to origin/main..."
echo "  (If prompted, authenticate with GitHub CLI or a Personal Access Token)"
echo "  (NEVER paste a token into a file — use 'gh auth login' or paste at the prompt)"
git push -u origin main

# ---------- 5. Optionally tag v0.1.0 ----------
echo ""
read -rp "==> Tag v0.1.0 and push to trigger the ISO build? [Y/n]: " TAG_ANS
TAG_ANS="${TAG_ANS:-Y}"
if [[ "${TAG_ANS,,}" == "y" ]]; then
  echo "==> Creating tag v0.1.0..."
  git tag -a v0.1.0 -m "Lumina Linux v0.1.0 — first release"
  git push origin v0.1.0
  echo ""
  echo "==> Build triggered!"
  echo "  Watch at: https://github.com/salom600/links/actions"
  echo "  ISO will appear at: https://github.com/salom600/links/releases"
  echo "  Expected build time: 45-75 minutes"
else
  echo ""
  echo "==> Skipped tagging. To trigger a build later:"
  echo "    git tag -a v0.1.0 -m 'First release' && git push origin v0.1.0"
  echo ""
  echo "  Or trigger manually from:"
  echo "    https://github.com/salom600/links/actions/workflows/build-iso.yml"
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
