#!/bin/bash
# Questao 24 (extra): estender vg_data/lv_data para 600 MiB. O VG nasce numa
# particao de 400 MiB, entao e' obrigatorio criar outra particao no espaco livre
# do disco de 6 GiB, pvcreate + vgextend + lvextend -r.
# lv_data comeca com 300 MiB porque o xfsprogs do RHEL 10 recusa XFS < 300 MB.
# Com EXAMSIM_VGDATA_PART definido (prova examsim-full) usa essa particao ja
# criada e nao mexe no resto do disco.
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 6) || { echo "ERRO: disco de 6GB nao encontrado"; exit 1; }
MNT=/mnt/examsim-data

umount "$MNT" 2>/dev/null
sed -i '\#/mnt/examsim-data#d; \#vg_data#d' /etc/fstab
vgremove -ff vg_data &>/dev/null

if [ -n "${EXAMSIM_VGDATA_PART:-}" ]; then
    PART=$EXAMSIM_VGDATA_PART
else
    limpa_disco_forte "$DISCO"
    parted -s "$DISCO" mklabel gpt mkpart data 1MiB 401MiB
    partprobe "$DISCO" 2>/dev/null; udevadm settle 2>/dev/null
    PART=$(lsblk -nrpo NAME,TYPE "$DISCO" | awk '$2=="part"{print $1; exit}')
fi
[ -b "${PART:-}" ] || { echo "ERRO: particao do vg_data nao existe (${PART:-vazia})"; exit 1; }

wipefs -a "$PART" &>/dev/null
pvcreate -ff -y "$PART" &>/dev/null
vgcreate vg_data "$PART" &>/dev/null || { echo "ERRO: vgcreate vg_data falhou em $PART"; exit 1; }
lvcreate -y -L 300M -n lv_data vg_data &>/dev/null || { echo "ERRO: lvcreate lv_data falhou"; exit 1; }
mkfs.xfs -q -f /dev/vg_data/lv_data || { echo "ERRO: mkfs.xfs falhou"; exit 1; }
mkdir -p "$MNT"
echo "/dev/mapper/vg_data-lv_data $MNT xfs defaults 0 0" >> /etc/fstab
systemctl daemon-reload
mount "$MNT" || { echo "ERRO: nao consegui montar $MNT"; exit 1; }
echo "dado de teste -- deve sobreviver ao vgextend/lvextend" > "$MNT/teste-examsim24.txt"
echo "OK: vg_data ($PART) + lv_data 300 MiB xfs montado em $MNT -- questao 24 pronta (estenda para 600 MiB)."
