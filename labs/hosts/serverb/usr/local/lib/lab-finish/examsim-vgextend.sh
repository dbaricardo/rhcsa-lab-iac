#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
umount /mnt/examsim-data 2>/dev/null
sed -i '\#/mnt/examsim-data#d; \#vg_data#d' /etc/fstab
PVS=$(pvs --noheadings -o pv_name -S vg_name=vg_data 2>/dev/null)
vgremove -ff vg_data &>/dev/null
for pv in $PVS; do pvremove -ff -y "$pv" &>/dev/null; done
DISCO=$(resolve_disco 6) && limpa_disco_forte "$DISCO"
systemctl daemon-reload
rmdir /mnt/examsim-data 2>/dev/null
echo "OK: questao 24 limpa (vg_data removido, disco de 6 GiB zerado)."
