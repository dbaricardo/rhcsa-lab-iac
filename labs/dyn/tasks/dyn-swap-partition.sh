# Dominio 4 / swap: particao de swap persistente. Params: DSIZE SIZE
ID=dyn-swap-partition
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "disco $D limpo, sem tabela de particoes."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    [ -b "$P" ]; check $? "a particao $P existe"
    mb=$(( $(blockdev --getsize64 "$P" 2>/dev/null || echo 0) / 1048576 ))
    [ "$mb" -ge $((SIZE * 85 / 100)) ] && [ "$mb" -le $((SIZE * 115 / 100)) ]
    check $? "a particao tem ~$SIZE MB (atual: $mb MB)"
    [ "$(blkid -s TYPE -o value "$P" 2>/dev/null)" = swap ]; check $? "$P esta formatada como swap"
    swapon --noheadings --show=NAME | grep -qxF "$P"; check $? "a swap em $P esta ativa"
    u=$(dev_uuid "$P")
    awk -v p="$P" -v u="UUID=$u" '$1 !~ /^#/ && $3=="swap" && ($1==p || $1==u){f=1} END{exit !f}' /etc/fstab
    check $? "o /etc/fstab tem a entrada de swap de $P (por UUID ou caminho)"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado e swap desativada."
}
run "$@"
