# Dominio 6 / systemd_timers: par .service + .timer com OnCalendar. Params: NAME CMD SCHEDULE SCHEDDESC
ID=dyn-timer-create
do_start() { unit_purge "$NAME"; echo "$NAME.service e $NAME.timer nao existem."; }
do_grade() {
    timer_files_ok "$NAME" "$CMD"
    local mine; mine=$(unit_key "/etc/systemd/system/$NAME.timer" OnCalendar)
    [ -n "$mine" ] && [ "$(cal_norm "$mine")" = "$(cal_norm "$SCHEDULE")" ]
    check $? "o OnCalendar e equivalente a $SCHEDULE (atual: ${mine:-nao definido})"
    timer_state_ok "$NAME"
    [ -n "$(systemctl show "$NAME.timer" -p NextElapseUSecRealtime --value 2>/dev/null)" ]; check $? "o timer tem uma proxima execucao agendada"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
