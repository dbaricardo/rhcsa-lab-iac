#!/bin/bash
set -u
umount /mnt/examsim-home 2>/dev/null
sed -i '\#/mnt/examsim-home#d' /etc/fstab
lvremove -ff myvg/home 2>/dev/null
vgremove -ff myvg 2>/dev/null
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) 2>/dev/null || DISCO=""
[ -n "$DISCO" ] && { pvremove -ff "$DISCO" 2>/dev/null; limpa_disco_forte "$DISCO"; }
rmdir /mnt/examsim-home 2>/dev/null
echo "OK: item 22 limpo."
