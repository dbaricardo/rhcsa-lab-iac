# Dominio 8 / scheduling: escrever a expressao cron certa. Params: EXPR EXPRDESC CMD (usuario: root)
ID=dyn-cron-expr
do_start() { cron_save "$ID" root; crontab -r -u root 2>/dev/null; echo "root nao tem crontab."; }
do_grade() {
    local linhas; linhas=$(crontab -l -u root 2>/dev/null | squeeze)
    echo "$linhas" | grep -qF -- "$CMD"; check $? "o comando $CMD esta no crontab de root"
    echo "$linhas" | grep -qxF -- "$EXPR $CMD"; check $? "o agendamento e exatamente \"$EXPR\" ($EXPRDESC)"
}
do_finish() { cron_restore "$ID" root; echo "limpeza: crontab de root restaurado."; }
run "$@"
