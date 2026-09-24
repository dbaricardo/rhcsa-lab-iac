#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. Antes de destruir o
# particionamento, captura os UUIDs das partições deste disco específico
# para remover só as linhas de /etc/fstab que este exercício adicionou --
# nunca uma entrada de swap/fs pré-existente de outro dispositivo do host.
set -uo pipefail
source /usr/local/lib/lab-common.sh 2>/dev/null || true

umount -f /appdata >/dev/null 2>&1 || true
sed -i '/[[:space:]]\/appdata[[:space:]]/d' /etc/fstab 2>/dev/null || true

disco="$(disco_por_tamanho 1 2>/dev/null || true)"
if [ -n "${disco:-}" ]; then
  for part in $(lsblk -nrpo NAME "$disco" 2>/dev/null | tail -n +2); do
    swapoff "$part" >/dev/null 2>&1 || true
    uuid="$(blkid -s UUID -o value "$part" 2>/dev/null || true)"
    if [ -n "$uuid" ]; then
      sed -i "/UUID=${uuid}/Id" /etc/fstab 2>/dev/null || true
    fi
    sed -i "\|^${part}[[:space:]]|d" /etc/fstab 2>/dev/null || true
  done
  wipefs -a "$disco" >/dev/null 2>&1 || true
fi

rmdir /appdata >/dev/null 2>&1 || true

echo "Ambiente de 'filesystems-01' limpo em $(hostname -s)."
exit 0
