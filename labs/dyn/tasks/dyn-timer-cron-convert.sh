# Dominio 6 / systemd_timers: converter uma linha de cron em timer. Params: NAME CMD CRON CRONDESC ONCAL
ID=dyn-timer-cron-convert
do_start() { unit_purge "$NAME"; echo "$NAME.service e $NAME.timer nao existem."; }
do_grade() {
    timer_files_ok "$NAME" "$CMD"
    local mine; mine=$(unit_key "/etc/systemd/system/$NAME.timer" OnCalendar)
    [ -n "$mine" ] && [ "$(cal_norm "$mine")" = "$(cal_norm "$ONCAL")" ]
    check $? "o OnCalendar equivale ao cron \"$CRON\" (atual: ${mine:-nao definido})"
    timer_state_ok "$NAME"
}
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
