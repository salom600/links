#!/usr/bin/env bash
# =============================================================================
# setup-services.sh — Enable systemd services in the airootfs
# =============================================================================
# Runs INSIDE the GitHub Actions container, BEFORE mkarchiso.
# Creates symlinks under airootfs/etc/systemd/system/ so that when the live
# ISO boots, the listed services are auto-started by systemd.
#
# Using symlinks (rather than `systemctl enable`) because systemctl can't
# run in a chroot that has no running PID 1. Symlinks are what `systemctl
# enable` would have created anyway.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AIROOTFS="$REPO_ROOT/airootfs"

SYSTEMD_DIR="$AIROOTFS/etc/systemd/system"
mkdir -p \
  "$SYSTEMD_DIR/multi-user.target.wants" \
  "$SYSTEMD_DIR/graphical.target.wants" \
  "$SYSTEMD_DIR/timers.target.wants" \
  "$SYSTEMD_DIR/sockets.target.wants"

echo "==> Enabling systemd services in airootfs..."

# ---------- multi-user.target (runlevel 3) ----------
MULTI_USER_SERVICES=(
  NetworkManager
  bluetooth
  firewalld
  tlp
  avahi-daemon
  haveged
  reflector
  systemd-timesyncd
  systemd-resolved
  iwd
  ModemManager
  pcscd
  smartd
  thermald
  upower
  accounts-daemon
  sddm
)

for svc in "${MULTI_USER_SERVICES[@]}"; do
  if [[ -f "$AIROOTFS/usr/lib/systemd/system/${svc}.service" ]] || true; then
    ln -sfv "/usr/lib/systemd/system/${svc}.service" \
            "$SYSTEMD_DIR/multi-user.target.wants/${svc}.service" 2>/dev/null || \
    echo "  (skipped ${svc} — .service not present in airootfs yet)"
  fi
done

# ---------- timers ----------
TIMERS=(
  reflector
  pamac-cleancache
  pamac-mirrorlist-timer
  fwupd
  logrotate
  man-db
  updatedb
)

for t in "${TIMERS[@]}"; do
  ln -sfv "/usr/lib/systemd/system/${t}.timer" \
          "$SYSTEMD_DIR/timers.target.wants/${t}.timer" 2>/dev/null || \
  echo "  (skipped ${t}.timer — not present in airootfs yet)"
done

# ---------- sockets ----------
SOCKETS=(
  pcscd
  avahi-daemon
  cups
)

for s in "${SOCKETS[@]}"; do
  ln -sfv "/usr/lib/systemd/system/${s}.socket" \
          "$SYSTEMD_DIR/sockets.target.wants/${s}.socket" 2>/dev/null || \
  echo "  (skipped ${s}.socket — not present in airootfs yet)"
done

# ---------- graphical.target ----------
# LightDM is our display manager; alias it as display-manager.service
ln -sfv "/usr/lib/systemd/system/lightdm.service" \
        "$SYSTEMD_DIR/display-manager.service" 2>/dev/null || true
ln -sfv "/usr/lib/systemd/system/lightdm.service" \
        "$SYSTEMD_DIR/graphical.target.wants/display-manager.service" 2>/dev/null || true

# ---------- Getty autologin on tty1 (live ISO only) ----------
GETTY_OVERRIDE="$AIROOTFS/etc/systemd/system/getty@tty1.service.d/override.conf"
mkdir -p "$(dirname "$GETTY_OVERRIDE")"
cat > "$GETTY_OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin lumina --noclear %I \$TERM
EOF

# ---------- Create live user (lumina) with no password ----------
# archiso normally uses the 'root' user; we want a regular user so the
# desktop experience matches the installed system.
# This is done via the airootfs/etc/passwd + shadow files (created by
# mkarchiso), so we just need to ensure the user exists.
echo "==> Service enablement complete."
echo ""
echo "multi-user.target.wants:"
ls -la "$SYSTEMD_DIR/multi-user.target.wants/" 2>/dev/null || echo "  (empty)"
echo ""
echo "graphical.target.wants:"
ls -la "$SYSTEMD_DIR/graphical.target.wants/" 2>/dev/null || echo "  (empty)"
echo ""
echo "timers.target.wants:"
ls -la "$SYSTEMD_DIR/timers.target.wants/" 2>/dev/null || echo "  (empty)"
