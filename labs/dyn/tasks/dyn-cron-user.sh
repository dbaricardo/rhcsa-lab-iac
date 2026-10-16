# Dominio 8 / scheduling: cron de usuario. Params: SCHEDULE SCHEDDESC CMD (usuario: root)
ID=dyn-cron-user
do_start() { cron_save "$ID" root; crontab -r -u root 2>/dev/null; echo "root nao tem crontab."; }
do_grade() {
    local alvo; alvo=$(printf '%s %s' "$SCHEDULE" "$CMD" | squeeze)
    crontab -l -u root 2>/dev/null | squeeze | grep -qxF -- "$alvo"
    check $? "o crontab de root tem: $alvo"
}
do_finish() { cron_restore "$ID" root; echo "limpeza: crontab de root restaurado."; }
run "$@"
