# Dominio 4 / lvm: VG com PE definido, LV em extents, mkfs, mount, fstab. Params: DSIZE VG LV PE EXT MOUNT
ID=dyn-lvm-extent-workflow
DEV=/dev/mapper/$VG-$LV
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "disco $D limpo, sem LVM."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    pe=$(vgs --noheadings --nosuffix --units m -o vg_extent_size "$VG" 2>/dev/null | awk '{printf "%d", $1}')
    [ "${pe:-0}" -eq "$PE" ]; check $? "o VG $VG tem extent de $PE MiB (atual: ${pe:-nao existe} MiB)"
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    le=$(( ${mb:-0} / ${PE} ))
    [ "$le" -eq "$EXT" ]; check $? "o volume logico $LV tem $EXT extents (atual: $le)"
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
