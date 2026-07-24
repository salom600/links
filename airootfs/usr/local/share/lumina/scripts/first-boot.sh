#!/usr/bin/env bash
# =============================================================================
# first-boot.sh — Runs ONCE on the installed system after Calamares finishes
# =============================================================================
# This is the post-install customization that the installer can't do directly:
#   1. Copy Lumina skeleton files to the new user's home
#   2. Set up Flatpak + Flathub
#   3. Set the GRUB theme
#   4. Enable reflector for fast mirrors
#   5. Add the user to the wheel, video, audio, etc. groups
#   6. Apply Btrfs snapshots config (if btrfs)
# =============================================================================

set -euo pipefail

NEW_USER="${1:-lumina}"
NEW_HOME="/home/${NEW_USER}"

echo "==> Lumina first-boot customization starting..."

# ---------- 1. Copy skel files to new user's home ----------
if [[ -d /etc/skel ]]; then
  echo "  -> Copying /etc/skel to ${NEW_HOME}"
  cp -ar /etc/skel/. "$NEW_HOME/"
  chown -R "${NEW_USER}:${NEW_USER}" "$NEW_HOME"
  chmod 700 "$NEW_HOME"
fi

# ---------- 2. Add user to supplementary groups ----------
echo "  -> Adding ${NEW_USER} to supplementary groups"
usermod -aG wheel,video,audio,input,storage,optical,lp,scanner,network,dbus,power,uucp,gamemode "$NEW_USER" || true

# ---------- 3. Set up Flathub ----------
if command -v flatpak >/dev/null; then
  echo "  -> Adding Flathub repo"
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
fi

# ---------- 4. Enable reflector for fastest mirrors ----------
if command -v reflector >/dev/null; then
  echo "  -> Refreshing Arch mirrorlist with reflector"
  reflector --latest 50 --protocol https --sort rate \
            --save /etc/pacman.d/mirrorlist 2>/dev/null || true
fi

# ---------- 5. Initialize pacman keyring on installed system ----------
echo "  -> Initializing pacman keyring"
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux 2>/dev/null || true

# ---------- 6. Snapper config for btrfs (if / is btrfs) ----------
if findmnt -no FSTYPE / 2>/dev/null | grep -q btrfs; then
  echo "  -> Setting up snapper for btrfs"
  if command -v snapper >/dev/null; then
    snapper -c root create-config /
    systemctl enable --now snapper-timeline.timer snapper-cleanup.timer 2>/dev/null || true
  fi
fi

# ---------- 7. Apply Lumina GRUB theme ----------
if [[ -d /usr/share/grub/themes/lumina ]]; then
  echo "  -> Applying Lumina GRUB theme"
  if grep -q "^GRUB_THEME=" /etc/default/grub; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/usr/share/grub/themes/lumina/theme.txt\"|" /etc/default/grub
  else
    echo "GRUB_THEME=\"/usr/share/grub/themes/lumina/theme.txt\"" >> /etc/default/grub
  fi
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# ---------- 8. Enable os-prober (so Windows shows in GRUB) ----------
if grep -q "^#GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
  sed -i 's|^#GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub
elif ! grep -q "^GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
  echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

# ---------- 9. Disable the getty autologin override (live ISO only) ----------
if [[ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]]; then
  echo "  -> Removing live-ISO getty autologin"
  rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
  rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null || true
fi

# ---------- 10. Mark welcome app as not-seen (so it shows on first login) ----------
if [[ -d "$NEW_HOME/.config" ]]; then
  rm -f "$NEW_HOME/.config/lumina/welcome-seen"
fi

# ---------- 11. Refresh package databases ----------
echo "  -> Refreshing pacman databases"
pacman -Sy 2>/dev/null || true

# ---------- 12. Mark as done ----------
echo "  -> Done."
echo "==> Lumina Linux is ready. Reboot to start using your new system."
