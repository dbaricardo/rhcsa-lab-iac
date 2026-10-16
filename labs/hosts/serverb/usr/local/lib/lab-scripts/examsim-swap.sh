#!/bin/bash
# Item 19: a particao de pratica ja existe; disponibilize-a como swap de 250 MiB.
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) || { echo "ERRO: disco de 1GB nao encontrado"; exit 1; }
PART="${DISCO}1"
if [ ! -b "$PART" ]; then
    parted -s "$DISCO" mklabel gpt mkpart primary 1MiB 251MiB
    partprobe "$DISCO" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
fi
[ -b "$PART" ] || { echo "ERRO: particao de pratica $PART nao existe"; exit 1; }
SIZE=$(lsblk -bno SIZE "$PART" 2>/dev/null | tr -d ' ')
[ -n "$SIZE" ] && [ "$SIZE" -ge 245000000 ] && [ "$SIZE" -le 270000000 ] || {
    echo "ERRO: $PART nao tem aproximadamente 250 MiB (tamanho: ${SIZE:-desconhecido})"; exit 1;
}
swapoff "$PART" 2>/dev/null || true
sed -i "\#${PART}#d" /etc/fstab
wipefs -a "$PART" &>/dev/null || true
echo "OK: $PART preservada e sem swap ativo -- item 19 pronto (configure 250 MiB)."
