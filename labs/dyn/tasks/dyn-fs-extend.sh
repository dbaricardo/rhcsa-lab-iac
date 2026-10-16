# Dominio 4 / filesystems: crescer ext4 montado sobre LV. Params: DSIZE SUFFIX EXPECTED
ID=dyn-fs-extend
VG=vg_prac$SUFFIX; LV=lv_prac$SUFFIX; MP=/mnt/practice_extend$SUFFIX; DEV=/dev/mapper/$VG-$LV
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    lvcreate -y -L 100M -n "$LV" "$VG" &>/dev/null || { echo "ERRO: lvcreate falhou"; exit 1; }
    mkfs.ext4 -q -F "$DEV" || exit 1
    mkdir -p "$MP"; mount "$DEV" "$MP" || exit 1
    echo dados-dyn > "$MP/dyn-marker.txt"
    echo "$DEV (ext4, 100 MB) montado em $MP com dados."
}
do_grade() {
    tipo=$(blkid -s TYPE -o value "$DEV" 2>/dev/null)
    [ "$tipo" = ext4 ]; check $? "o filesystem ext4 continua em $DEV (atual: ${tipo:-nenhum})"
    findmnt -nro SOURCE "$MP" | grep -q .; check $? "o filesystem continua montado em $MP (sem desmontar)"
    fsmb=$(dumpe2fs -h "$DEV" 2>/dev/null | awk -F: '/^Block count/{c=$2} /^Block size/{b=$2} END{printf "%d", c*b/1048576}')
    [ "${fsmb:-0}" -ge $((EXPECTED * 90 / 100)) ] && [ "${fsmb:-0}" -le $((EXPECTED * 130 / 100)) ]
    check $? "o filesystem tem ~$EXPECTED MB (atual: ~${fsmb:-0} MB)"
    [ "$(cat "$MP/dyn-marker.txt" 2>/dev/null)" = dados-dyn ]; check $? "os dados originais continuam intactos"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MP" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
