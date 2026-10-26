# Dominio 5 / networking: hostname estatico. Params: NEWNAME
ID=dyn-net-hostname
do_start() {
    [ -e "$ST/$ID.orig" ] || { n=$(hostnamectl --static 2>/dev/null); echo "${n:-localhost.localdomain}" > "$ST/$ID.orig"; }
    if [ "$(hostname)" = "$NEWNAME" ]; then hostnamectl set-hostname "antes-$RANDOM.lab.example.com"; fi
    echo "hostname atual: $(hostname); a questao pede $NEWNAME."
}
do_grade() {
    [ "$(hostname)" = "$NEWNAME" ]; check $? "hostname atual e $NEWNAME (atual: $(hostname))"
    [ "$(hostnamectl --static 2>/dev/null)" = "$NEWNAME" ]; check $? "hostname estatico e $NEWNAME"
    grep -qx "$NEWNAME" /etc/hostname 2>/dev/null; check $? "/etc/hostname contem $NEWNAME"
}
do_finish() {
    [ -s "$ST/$ID.orig" ] && hostnamectl set-hostname "$(cat "$ST/$ID.orig")"
    rm -f "$ST/$ID.orig"
    echo "limpeza: hostname restaurado para $(hostname)."
}
run "$@"
