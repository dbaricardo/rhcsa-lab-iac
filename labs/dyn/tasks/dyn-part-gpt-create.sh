# Dominio 4 / partitioning: tabela GPT + 1 particao nomeada. Params: DSIZE SIZE PNAME
ID=dyn-part-gpt-create
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "disco $D limpo, sem tabela de particoes."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    parted -s "$D" print 2>/dev/null | grep -qi 'Partition Table: gpt'; check $? "o disco $D tem tabela de particoes GPT"
    [ -b "$P" ]; check $? "a particao $P existe"
    mb=$(( $(blockdev --getsize64 "$P" 2>/dev/null || echo 0) / 1048576 ))
    [ "$mb" -ge $((SIZE * 85 / 100)) ] && [ "$mb" -le $((SIZE * 115 / 100)) ]
    check $? "a particao tem ~$SIZE MiB (atual: $mb MiB)"
    nome=$(parted -sm "$D" print 2>/dev/null | awk -F: '$1==1{print $6}')
    [ "$nome" = "$PNAME" ]; check $? "a particao se chama '$PNAME' (atual: '${nome:-sem nome}')"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
