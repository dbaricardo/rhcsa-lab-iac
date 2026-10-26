# Dominio 8 / scheduling: listar e salvar o cron de um usuario. Params: ACCT OUTFILE
ID=dyn-cron-list
do_start() {
    user_mk "$ACCT" -m || exit 1
    printf '%s\n' '0 5 * * * /bin/true # dyn-backup' '*/10 * * * * /bin/true # dyn-check' | crontab -u "$ACCT" -
    safe_rm "$OUTFILE"
    echo "o usuario $ACCT tem 2 jobs de cron; $OUTFILE nao existe."
}
do_grade() {
    [ -s "$OUTFILE" ]; check $? "o arquivo $OUTFILE existe e nao esta vazio"
    diff -q <(crontab -l -u "$ACCT" 2>/dev/null) "$OUTFILE" &>/dev/null
    check $? "$OUTFILE tem exatamente a listagem do crontab de $ACCT"
    grep -q 'dyn-backup' "$OUTFILE" 2>/dev/null && grep -q 'dyn-check' "$OUTFILE" 2>/dev/null
    check $? "os 2 jobs de $ACCT estao no arquivo"
}
do_finish() { user_purge "$ACCT"; safe_rm "$OUTFILE"; echo "limpeza: usuario $ACCT e $OUTFILE removidos."; }
run "$@"
