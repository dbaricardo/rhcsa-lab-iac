# Dominio 4 / lvm: remover um LV montado e no fstab. Params: DSIZE VG LV
ID=dyn-lvm-lv-remove
MP=/mnt/$LV; DEV=/dev/mapper/$VG-$LV
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    lvcreate -y -L 100M -n "$LV" "$VG" &>/dev/null || { echo "ERRO: lvcreate falhou"; exit 1; }
    mkfs.ext4 -q -F "$DEV" || exit 1
    mkdir -p "$MP"; mount "$DEV" "$MP" || exit 1
    echo "$DEV $MP ext4 defaults 0 0" >> /etc/fstab
    systemctl daemon-reload
    echo "$VG/$LV (100 MB) montado em $MP e presente no fstab."
}
do_grade() {
    ! lvs --noheadings "$VG/$LV" &>/dev/null; check $? "o volume logico $VG/$LV foi removido"
    ! findmnt -rn "$MP" >/dev/null; check $? "$MP nao esta mais montado"
    ! awk -v m="$MP" -v d="$DEV" -v d2="/dev/$VG/$LV" '$1 !~ /^#/ && ($2==m || $1==d || $1==d2){f=1} END{exit !f}' /etc/fstab
    check $? "nao sobrou entrada no /etc/fstab para $LV"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MP" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
