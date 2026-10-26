#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) || exit 0
PART="${DISCO}1"
swapoff "$PART" 2>/dev/null || true
sed -i "\#${PART}#d" /etc/fstab
[ -b "$PART" ] && wipefs -a "$PART" &>/dev/null || true
echo "OK: item 19 limpo; particao de pratica preservada."
