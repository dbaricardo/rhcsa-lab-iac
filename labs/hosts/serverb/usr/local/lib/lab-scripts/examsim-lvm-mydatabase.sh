#!/bin/bash
# Item 20: VG (PE 8MiB), LV mydatabase (50 PE), vfat, montado em /database.
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) || { echo "ERRO: disco de 1GB nao encontrado"; exit 1; }
umount /database 2>/dev/null
sed -i '\#/database#d' /etc/fstab
vgremove -ff myvg 2>/dev/null
limpa_disco_forte "$DISCO"
rmdir /database 2>/dev/null
echo "OK: $DISCO limpo -- item 20 pronto."
