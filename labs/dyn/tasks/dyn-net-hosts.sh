# Dominio 5 / networking: entrada em /etc/hosts. Params: IP FQDN SHORT
ID=dyn-net-hosts
do_start() {
    [ -e "$ST/$ID.hosts" ] || cp -p /etc/hosts "$ST/$ID.hosts"
    awk -v f="$FQDN" -v s="$SHORT" '/^[[:space:]]*#/ {print; next}
        {drop=0; for (i=2; i<=NF; i++) if ($i==f || $i==s) drop=1} !drop' /etc/hosts > "$ST/$ID.tmp" \
        && cat "$ST/$ID.tmp" > /etc/hosts
    rm -f "$ST/$ID.tmp"
    echo "/etc/hosts sem entradas para $FQDN / $SHORT."
}
do_grade() {
    awk -v f="$FQDN" '/^[[:space:]]*#/ {next} {for (i=2; i<=NF; i++) if ($i==f) found=1} END{exit !found}' /etc/hosts
    check $? "$FQDN presente em /etc/hosts"
    got=$(getent hosts "$FQDN" | awk '{print $1; exit}')
    [ "$got" = "$IP" ]; check $? "$FQDN resolve para $IP (atual: ${got:-nada})"
    got=$(getent hosts "$SHORT" | awk '{print $1; exit}')
    [ "$got" = "$IP" ]; check $? "nome curto $SHORT resolve para $IP (atual: ${got:-nada})"
}
do_finish() {
    [ -e "$ST/$ID.hosts" ] && cp -p "$ST/$ID.hosts" /etc/hosts
    rm -f "$ST/$ID.hosts"
    echo "limpeza: /etc/hosts original restaurado."
}
run "$@"
