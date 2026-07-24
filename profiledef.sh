#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Lumina Linux — ISO profile definition
# Used by `mkarchiso` to identify the ISO and its layout.
#

iso_name="lumina"
iso_label="LUMINA_$(date +%Y%m)"
iso_publisher="Lumina Linux Project <https://github.com/salom600/links>"
iso_application="Lumina Linux Live/Install ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
# Boot modes — uses the NEW (post-archiso v67) simplified names.
#   bios.syslinux        = BIOS boot via syslinux (REMOVED — syslinux package
#                          was dropped from Arch official repos in 2025 and is
#                          now AUR-only. Most modern systems use UEFI anyway.)
#   uefi.systemd-boot    = UEFI boot via systemd-boot (combines the old .esp
#                          and .eltorito modes)
# The old names (bios.syslinux.mbr, bios.syslinux.eltorito,
# uefi-x64.systemd-boot.esp, uefi-x64.systemd-boot.eltorito) are deprecated
# and emit warnings in current archiso; some versions reject them entirely.
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ['/usr/local/bin/lumina-welcome']='0:0:755'
  ['/usr/local/bin/lumina-toggle-effects']='0:0:755'
  ['/usr/local/bin/lumina-installer']='0:0:755'
  ['/usr/local/share/lumina/scripts/first-boot.sh']='0:0:755'
)
