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
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-x64.systemd-boot.esp'
           'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ['/etc/shadow']='0:0:400'
  ['/etc/gshadow']='0:0:400'
  ['/usr/local/bin/lumina-welcome']='0:0:755'
  ['/usr/local/bin/lumina-toggle-effects']='0:0:755'
  ['/usr/local/bin/lumina-installer']='0:0:755'
  ['/root/.automated_script.sh']='0:0:755'
  ['/root/.gnupg']='0:0:700'
  ['/usr/local/share/lumina/scripts/first-boot.sh']='0:0:755'
)
