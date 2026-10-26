#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
MNT=/treino
ESTADO=/var/lib/rhcsa-treino

systemctl disable --now treino-marca.timer &>/dev/null
rm -f /etc/systemd/system/treino-marca.timer /etc/systemd/system/treino-marca.service
rm -f /usr/local/bin/treino-marca.sh
umount "$MNT" 2>/dev/null
sed -i '\#[[:space:]]/treino[[:space:]]#d; \#vgtreino#d' /etc/fstab
DISCO=$(resolve_disco 6) && {
    for p in $(lsblk -nrpo NAME,TYPE "$DISCO" | awk '$2=="part"{print $1}'); do
        u=$(blkid -s UUID -o value "$p" 2>/dev/null)
        swapoff "$p" 2>/dev/null
        [ -n "$u" ] && sed -i "\#UUID=$u#d" /etc/fstab
        sed -i "\#^${p}[[:space:]]#d" /etc/fstab
    done
}
vgremove -ff vgtreino &>/dev/null
[ -n "${DISCO:-}" ] && limpa_disco_forte "$DISCO"
systemctl daemon-reload
rm -rf "$MNT"
# O historico de tempos fica: e' ele que mostra a evolucao entre os dias.
rm -f "$ESTADO/inicio"
echo "OK: questao 25 limpa (swap, vgtreino, /treino e timer removidos; disco de 6 GiB zerado)."
[ -s "$ESTADO/historico" ] && { echo "Historico de tempos:"; cat "$ESTADO/historico"; }
exit 0
