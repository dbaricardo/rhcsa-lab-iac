# Dominio 4 / lvm: criar LV (em MB ou extents) num VG existente. Params: DSIZE VG LV MODE PE [SIZE|EXT]
ID=dyn-lvm-lv-create
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    pvcreate -ff -y "$D" &>/dev/null && vgcreate -s "${PE}M" "$VG" "$D" &>/dev/null || { echo "ERRO: pvcreate/vgcreate falhou"; exit 1; }
    echo "VG $VG criado em $D (extent de $PE MiB), sem volumes logicos."
}
do_grade() {
    lvs --noheadings "$VG/$LV" &>/dev/null; check $? "o volume logico $VG/$LV existe"
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    if [ "$MODE" = ext ]; then
        le=$(( ${mb:-0} / PE ))
        [ "$le" -eq "$EXT" ]; check $? "$LV tem $EXT extents de $PE MiB (atual: $le)"
    else
        [ "${mb:-0}" -ge $((SIZE * 95 / 100)) ] && [ "${mb:-0}" -le $((SIZE * 105 / 100)) ]
        check $? "$LV tem ~$SIZE MB (atual: ${mb:-0} MB)"
    fi
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
