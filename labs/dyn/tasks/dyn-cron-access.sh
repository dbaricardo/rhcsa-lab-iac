# Dominio 8 / scheduling: restringir quem usa o cron. Params: ACCT OTHER METHOD(deny|allow)
ID=dyn-cron-access
usa() { runuser -u "$1" -- crontab -l 2>&1; }   # saida contem "not allowed" quando barrado
do_start() {
    conf_save /etc/cron.deny "$ID.deny"; conf_save /etc/cron.allow "$ID.allow"
    user_mk "$ACCT" -m || exit 1
    user_mk "$OTHER" -m || exit 1
    sed -i "/^$ACCT\$/d;/^$OTHER\$/d" /etc/cron.deny 2>/dev/null
    rm -f /etc/cron.allow
    echo "$ACCT e $OTHER existem e os dois podem usar o crontab."
}
do_grade() {
    if [ "$METHOD" = deny ]; then
        grep -qxF "$ACCT" /etc/cron.deny 2>/dev/null; check $? "$ACCT esta em /etc/cron.deny"
        usa "$ACCT" | grep -q 'not allowed'; check $? "$ACCT nao consegue mais usar o crontab"
        ! usa "$OTHER" | grep -q 'not allowed'; check $? "$OTHER continua podendo usar o crontab (so $ACCT deveria ser barrado)"
    else
        grep -qxF "$ACCT" /etc/cron.allow 2>/dev/null; check $? "$ACCT esta em /etc/cron.allow"
        ! usa "$ACCT" | grep -q 'not allowed'; check $? "$ACCT pode usar o crontab"
        usa "$OTHER" | grep -q 'not allowed'; check $? "$OTHER (fora da lista) nao pode usar o crontab"
    fi
}
do_finish() {
    conf_restore /etc/cron.deny "$ID.deny"; conf_restore /etc/cron.allow "$ID.allow"
    user_purge "$ACCT"; user_purge "$OTHER"
    echo "limpeza: cron.allow/cron.deny restaurados e usuarios removidos."
}
run "$@"
