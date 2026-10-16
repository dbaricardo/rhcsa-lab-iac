#!/bin/bash
set -u
umount /database 2>/dev/null
sed -i '\#/database#d' /etc/fstab
lvremove -ff myvg/mydatabase 2>/dev/null
vgremove -ff myvg 2>/dev/null
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) 2>/dev/null || DISCO=""
[ -n "$DISCO" ] && { pvremove -ff "$DISCO" 2>/dev/null; limpa_disco_forte "$DISCO"; }
rmdir /database 2>/dev/null
echo "OK: item 20 limpo."
