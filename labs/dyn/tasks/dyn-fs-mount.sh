# Dominio 4 / filesystems: montar um filesystem existente. Params: DSIZE MOUNT
ID=dyn-fs-mount
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 501 || exit 1
    P=$(disk_part "$D" 1); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
    mkfs.ext4 -q -F "$P" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "$P esta formatada em ext4 e desmontada."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    findmnt -rn "$MOUNT" >/dev/null; check $? "ha algo montado em $MOUNT"
    fonte=$(findmnt -nro SOURCE "$MOUNT" 2>/dev/null | head -1)
    [ "$fonte" = "$P" ]; check $? "o que esta em $MOUNT e $P (atual: ${fonte:-nada})"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
