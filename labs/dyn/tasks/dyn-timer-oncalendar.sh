# Dominio 6 / systemd_timers: timer com horario de calendario. Params: NAME CMD SCHEDULE SCHEDDESC
ID=dyn-timer-oncalendar
do_start() { unit_purge "$NAME"; echo "$NAME.service e $NAME.timer nao existem."; }
do_grade() {
    timer_files_ok "$NAME" "$CMD"
    local mine; mine=$(unit_key "/etc/systemd/system/$NAME.timer" OnCalendar)
    [ -n "$mine" ] && [ "$(cal_norm "$mine")" = "$(cal_norm "$SCHEDULE")" ]
    check $? "o OnCalendar e equivalente a $SCHEDULE (atual: ${mine:-nao definido})"
    grep -qs '^WantedBy=timers.target' "/etc/systemd/system/$NAME.timer"; check $? "o timer tem [Install] WantedBy=timers.target (persiste no boot)"
    timer_state_ok "$NAME"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
