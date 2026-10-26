# Dominio 8 / scheduling: cron do sistema em /etc/cron.d. Params: JOB RUNAS CMD SCHEDULE SCHEDDESC
ID=dyn-cron-system
do_start() { safe_rm "/etc/cron.d/$JOB"; echo "/etc/cron.d/$JOB nao existe."; }
do_grade() {
    local f=/etc/cron.d/$JOB
    [ -f "$f" ]; check $? "o arquivo $f existe"
    squeeze < "$f" 2>/dev/null | grep -qxF -- "$SCHEDULE $RUNAS $CMD"
    check $? "o arquivo tem a linha \"$SCHEDULE $RUNAS $CMD\" (formato do sistema: com o campo de usuario)"
    [ -f "$f" ] && [ $(( 0$(stat -c %a "$f") & 022 )) -eq 0 ] && [ "$(stat -c %U "$f")" = root ]
    check $? "o arquivo e de root e nao e gravavel por outros (o cron ignora arquivos inseguros)"
}
do_finish() { safe_rm "/etc/cron.d/$JOB"; echo "limpeza: /etc/cron.d/$JOB removido."; }
run "$@"
