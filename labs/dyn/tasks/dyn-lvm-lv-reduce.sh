# Dominio 4 / lvm: reduzir LV ext4 montado. Params: DSIZE VG LV NEWSIZE
ID=dyn-lvm-lv-reduce
MP=/mnt/$LV; DEV=/dev/mapper/$VG-$LV
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    lvcreate -y -L 350M -n "$LV" "$VG" &>/dev/null || { echo "ERRO: lvcreate falhou"; exit 1; }
    mkfs.ext4 -q -F "$DEV" || exit 1
    mkdir -p "$MP"; mount "$DEV" "$MP" || exit 1
    echo dados-dyn > "$MP/dyn-marker.txt"
    echo "$VG/$LV (350 MB, ext4) montado em $MP com dados."
}
do_grade() {
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    [ "${mb:-0}" -ge $((NEWSIZE * 90 / 100)) ] && [ "${mb:-0}" -le $((NEWSIZE * 105 / 100)) ]
    check $? "$LV foi reduzido para ~$NEWSIZE MB (atual: ${mb:-0} MB)"
    [ "$(blkid -s TYPE -o value "$DEV" 2>/dev/null)" = ext4 ]; check $? "o filesystem ext4 continua integro em $LV"
    fsmb=$(dumpe2fs -h "$DEV" 2>/dev/null | awk -F: '/^Block count/{c=$2} /^Block size/{b=$2} END{printf "%d", c*b/1048576}')
    [ "${fsmb:-9999}" -le "${mb:-0}" ]; check $? "o filesystem cabe no LV (fs ~${fsmb:-?} MB, LV ${mb:-0} MB)"
    findmnt -nro SOURCE "$MP" | grep -q .; check $? "$LV foi montado de novo em $MP"
    [ "$(cat "$MP/dyn-marker.txt" 2>/dev/null)" = dados-dyn ]; check $? "os dados originais continuam intactos"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MP" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
