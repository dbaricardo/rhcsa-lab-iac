#!/bin/bash
# Solução de referência para storage-lvm-01 (host: serverb). Idempotente.
set -euo pipefail
source /usr/local/lib/lab-common.sh

if lvs --noheadings -o lv_name vg_conteudo/lv_midia >/dev/null 2>&1; then
  echo "storage-lvm-01: LVM já configurado, só garantindo o mount."
else
  disco="$(disco_por_tamanho 6)"
  [ -n "$disco" ] || {
    echo "storage-lvm-01: disco de ~6GB não encontrado em $(hostname -s)" >&2
    exit 1
  }
  wipefs -a "$disco" >/dev/null 2>&1 || true
  pvcreate -f "$disco"
  vgcreate vg_conteudo "$disco"
  lvcreate -L 5G -n lv_midia vg_conteudo
  mkfs.xfs -f /dev/vg_conteudo/lv_midia
fi

mkdir -p /midia
uuid="$(blkid -s UUID -o value /dev/vg_conteudo/lv_midia)"
grep -q "$uuid" /etc/fstab 2>/dev/null \
  || echo "UUID=${uuid} /midia xfs defaults 0 0" >> /etc/fstab

mountpoint -q /midia || mount /midia

echo "storage-lvm-01: solução aplicada em $(hostname -s)."
