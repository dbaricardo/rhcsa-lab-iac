# Dominio 4 / lvm: estender um LV existente. Params: DSIZE VG LV MODE PE INITMB TARGET
ID=dyn-lvm-extend
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate -s "${PE}M" "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    lvcreate -y -L "${INITMB}M" -n "$LV" "$VG" &>/dev/null || { echo "ERRO: lvcreate falhou"; exit 1; }
    echo "$VG/$LV criado com $INITMB MB; o VG tem espaco livre."
}
do_grade() {
    lvs --noheadings "$VG/$LV" &>/dev/null; check $? "o volume logico $VG/$LV existe"
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    if [ "$MODE" = ext ]; then
        le=$(( ${mb:-0} / PE ))
        [ "$le" -eq "$TARGET" ]; check $? "$LV tem $TARGET extents no total (atual: $le)"
    else
        [ "${mb:-0}" -ge $((TARGET * 95 / 100)) ]; check $? "$LV foi estendido para ~$TARGET MB (atual: ${mb:-0} MB)"
    fi
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
