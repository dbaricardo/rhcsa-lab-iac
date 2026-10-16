# Dominio 3 / users_groups: grupos suplementares sem perder os atuais. Params: ACCT GROUPS (separados por espaco)
ID=dyn-user-groups
KEEP=keepgrp
do_start() {
    rm -f "${ST:?}/${ID:?}.groups"
    for g in $GROUPS_LIST; do getent group "$g" &>/dev/null && { echo "ERRO: o grupo $g ja existe; rode o lab start de novo"; exit 1; }; done
    grp_mk "$KEEP$ACCT"
    user_mk "$ACCT" -m -G "$KEEP$ACCT" || exit 1
    echo "o usuario $ACCT existe e ja pertence a $KEEP$ACCT; os grupos pedidos ainda nao existem."
}
do_grade() {
    id "$ACCT" &>/dev/null; check $? "o usuario $ACCT existe"
    for g in $GROUPS_LIST; do
        getent group "$g" &>/dev/null; check $? "o grupo $g existe"
        id -nG "$ACCT" 2>/dev/null | tr ' ' '\n' | grep -qxF "$g"; check $? "$ACCT e membro suplementar de $g"
    done
    id -nG "$ACCT" 2>/dev/null | tr ' ' '\n' | grep -qxF "$KEEP$ACCT"; check $? "$ACCT continua em $KEEP$ACCT (nao perdeu grupos: use usermod -aG)"
}
do_finish() {
    user_purge "$ACCT"
    for g in $GROUPS_LIST; do groupdel "$g" 2>/dev/null; done
    grp_purge
    echo "limpeza: usuario e grupos removidos."
}
run "$@"
