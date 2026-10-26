# Dominio 4 / lvm: PV, VG, LV, mkfs, mount, fstab. Params: DSIZE VG LV SIZE MOUNT
ID=dyn-lvm-full-workflow
DEV=/dev/mapper/$VG-$LV
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "disco $D limpo, sem LVM."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    pvs --noheadings -o pv_name 2>/dev/null | grep -qwF "$D"; check $? "$D e um volume fisico (PV)"
    vgs --noheadings "$VG" &>/dev/null; check $? "o grupo de volumes $VG existe"
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    [ "${mb:-0}" -ge $((SIZE * 95 / 100)) ] && [ "${mb:-0}" -le $((SIZE * 105 / 100)) ]
    check $? "o volume logico $LV tem ~$SIZE MB (atual: ${mb:-0} MB)"
    [ "$(blkid -s TYPE -o value "$DEV" 2>/dev/null)" = xfs ]; check $? "$LV esta formatado como xfs"
    findmnt -nro TARGET -S "$DEV" | grep -qxF "$MOUNT"; check $? "$LV esta montado em $MOUNT"
    u=$(dev_uuid "$DEV"); linha=$(fstab_line "$MOUNT"); src=${linha%% *}
    [ -n "$linha" ] && { [ "$src" = "UUID=$u" ] || [ "$src" = "$DEV" ] || [ "$src" = "/dev/$VG/$LV" ]; }
    check $? "o /etc/fstab tem uma entrada valida para $MOUNT"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
