# Dominio 6 / services: listar unidades com falha e salvar. Params: SVC OUTFILE
ID=dyn-svc-list-failed
do_start() {
    unit_purge "$SVC"; safe_rm "$OUTFILE"
    unit_mk "$SVC" "/usr/bin/false"
    systemctl start "$SVC" &>/dev/null
    echo "$SVC.service esta em estado failed; $OUTFILE nao existe."
}
do_grade() {
    [ -s "$OUTFILE" ]; check $? "o arquivo $OUTFILE existe e nao esta vazio"
    grep -qF "$SVC.service" "$OUTFILE" 2>/dev/null; check $? "a listagem inclui a unidade com falha $SVC.service"
    local u falta=0
    for u in $(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}'); do grep -qF "$u" "$OUTFILE" 2>/dev/null || falta=1; done
    check $falta "a listagem inclui todas as unidades que estao em failed agora"
}
do_finish() { unit_purge "$SVC"; safe_rm "$OUTFILE"; echo "limpeza: $SVC e $OUTFILE removidos."; }
run "$@"
