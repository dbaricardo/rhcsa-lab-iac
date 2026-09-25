#!/bin/bash
# Solução de referência para filesystems-01 (host: serverb). Idempotente.
# Usa disco_por_tamanho() (não resolve_disco()) porque, numa segunda
# execução, o disco já estará particionado -- ver o comentário em
# labs/filesystems-01/grade.sh sobre esse mesmo bug de helper.
set -euo pipefail
source /usr/local/lib/lab-common.sh

disco="$(disco_por_tamanho 1)"
[ -n "$disco" ] || {
  echo "filesystems-01: disco de ~1GB não encontrado em $(hostname -s)" >&2
  exit 1
}

part_count="$(lsblk -nrpo NAME,TYPE "$disco" | awk '$2=="part"' | wc -l)"
if [ "$part_count" -lt 2 ]; then
  wipefs -a "$disco" >/dev/null 2>&1 || true
  parted -s "$disco" mklabel msdos
  parted -s "$disco" mkpart primary ext4 1MiB 650MiB
  parted -s "$disco" mkpart primary linux-swap 650MiB 100%
  partprobe "$disco"
  udevadm settle
  mkfs.ext4 -F "${disco}1"
  mkswap -f "${disco}2"
fi

mkdir -p /appdata
uuid_ext4="$(blkid -s UUID -o value "${disco}1")"
grep -q "$uuid_ext4" /etc/fstab 2>/dev/null \
  || echo "UUID=${uuid_ext4} /appdata ext4 defaults 0 0" >> /etc/fstab
mountpoint -q /appdata || mount /appdata

uuid_swap="$(blkid -s UUID -o value "${disco}2")"
grep -q "$uuid_swap" /etc/fstab 2>/dev/null \
  || echo "UUID=${uuid_swap} swap swap defaults 0 0" >> /etc/fstab
swapon --show=NAME --noheadings | grep -q "${disco}2" || swapon "${disco}2"

echo "filesystems-01: solução aplicada em $(hostname -s)."
