# Dominio 4 / partitioning: remover uma particao montada. Params: DSIZE PNUM
ID=dyn-part-delete
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 101 201 301 || exit 1
    local n P u
    for n in 1 2 3; do
        P=$(disk_part "$D" $n); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
        mkfs.ext4 -q -F "$P" || exit 1
        mkdir -p "/mnt/dyndel$n"; mount "$P" "/mnt/dyndel$n" || exit 1
        u=$(dev_uuid "$P"); echo "UUID=$u /mnt/dyndel$n ext4 defaults 0 0" >> /etc/fstab
        [ "$n" = "$PNUM" ] && echo "$u" > "$ST/$ID.uuid"
    done
    systemctl daemon-reload
    echo "3 particoes em $D, montadas em /mnt/dyndel1..3 e no fstab."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" "$PNUM")
    [ ! -b "$P" ]; check $? "a particao $P foi removida"
    local n ok=0
    for n in 1 2 3; do
        [ "$n" = "$PNUM" ] && continue
        [ -b "$(disk_part "$D" $n)" ] || ok=1
    done
    check $ok "as outras particoes de $D continuam no lugar"
    ! findmnt -rn "/mnt/dyndel$PNUM" >/dev/null; check $? "/mnt/dyndel$PNUM nao esta mais montado"
    u=$(cat "$ST/$ID.uuid" 2>/dev/null)
    ! awk -v m="/mnt/dyndel$PNUM" -v u="UUID=$u" '$1 !~ /^#/ && ($2==m || $1==u){f=1} END{exit !f}' /etc/fstab
    check $? "nao sobrou entrada no /etc/fstab para a particao removida"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir /mnt/dyndel1 /mnt/dyndel2 /mnt/dyndel3 2>/dev/null
    rm -f "${ST:?}/${ID:?}.uuid"
    echo "limpeza: disco $D zerado."
}
run "$@"
