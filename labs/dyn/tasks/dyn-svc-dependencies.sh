# Dominio 6 / services: arvore de dependencias salva em arquivo. Params: SVC OUTFILE
ID=dyn-svc-dependencies
DEP=${SVC}dep
do_start() {
    unit_purge "$SVC"; unit_purge "$DEP"; safe_rm "$OUTFILE"
    unit_mk "$DEP" "/usr/bin/sleep infinity"
    UNIT_EXTRA="Wants=$DEP.service\nAfter=$DEP.service" unit_mk "$SVC" "/usr/bin/sleep infinity"
    echo "$SVC.service depende de $DEP.service; $OUTFILE nao existe."
}
do_grade() {
    [ -s "$OUTFILE" ]; check $? "o arquivo $OUTFILE existe e nao esta vazio"
    head -1 "$OUTFILE" 2>/dev/null | grep -qF "$SVC.service"; check $? "a primeira linha e a unidade $SVC.service (arvore completa)"
    grep -qF "$DEP.service" "$OUTFILE" 2>/dev/null; check $? "a arvore inclui a dependencia $DEP.service"
    grep -qE 'sysinit\.target|basic\.target' "$OUTFILE" 2>/dev/null; check $? "a arvore inclui as dependencias de sistema (sysinit.target/basic.target)"
    local real mine
    real=$(systemctl list-dependencies --plain --no-pager "$SVC" 2>/dev/null | wc -l); mine=$(wc -l < "$OUTFILE" 2>/dev/null || echo 0)
    [ "$mine" -ge $((real * 8 / 10)) ]; check $? "o arquivo tem a arvore inteira (~$real linhas; o arquivo tem $mine)"
}
do_finish() { unit_purge "$SVC"; unit_purge "$DEP"; safe_rm "$OUTFILE"; echo "limpeza: $SVC, $DEP e $OUTFILE removidos."; }
run "$@"
