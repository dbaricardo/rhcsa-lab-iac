# Dominio 6 / services: achar o PID do processo principal. Params: SVC PIDFILE
ID=dyn-svc-manage-proc
do_start() { unit_purge "$SVC"; safe_rm "$PIDFILE"; unit_mk "$SVC" "/usr/bin/sleep infinity"; echo "o servico $SVC.service esta parado; $PIDFILE nao existe."; }
do_grade() {
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ]; check $? "o servico $SVC esta em execucao"
    local pid; pid=$(systemctl show "$SVC" -p MainPID --value 2>/dev/null)
    [ -s "$PIDFILE" ]; check $? "o arquivo $PIDFILE existe e nao esta vazio"
    [ -n "$pid" ] && [ "$pid" != 0 ] && [ "$(tr -d '[:space:]' < "$PIDFILE" 2>/dev/null)" = "$pid" ]
    check $? "$PIDFILE contem o PID do processo principal (atual: ${pid:-nenhum})"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; check $? "o processo $pid esta vivo (o servico continua em execucao)"
}
do_finish() { unit_purge "$SVC"; safe_rm "$PIDFILE"; echo "limpeza: $SVC e $PIDFILE removidos."; }
run "$@"
