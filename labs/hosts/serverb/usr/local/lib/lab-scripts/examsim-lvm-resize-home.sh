#!/bin/bash
# Item 22: redimensionar o LV 'home' no VG 'myvg' para 152MB (38 extents,
# PE 4MiB default). Ponto de montagem de pratica: /mnt/examsim-home (nao
# o /home real do sistema -- decisao deliberada de seguranca, ver wiki).
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 1) || { echo "ERRO: disco de 1GB nao encontrado"; exit 1; }
umount /mnt/examsim-home 2>/dev/null
sed -i '\#/mnt/examsim-home#d' /etc/fstab
vgremove -ff myvg 2>/dev/null
limpa_disco_forte "$DISCO"
pvcreate -ff -y "$DISCO" &>/dev/null
vgcreate myvg "$DISCO" &>/dev/null
lvcreate -l 15 -n home myvg &>/dev/null
mkfs.ext4 -q /dev/myvg/home
mkdir -p /mnt/examsim-home
mount /dev/myvg/home /mnt/examsim-home
echo "arquivo de teste -- deve sobreviver ao resize" > /mnt/examsim-home/teste-examsim22.txt
echo "OK: VG myvg + LV home (15 extents) criado e montado em /mnt/examsim-home -- item 22 pronto (redimensione pra 152MB/38 extents)."
