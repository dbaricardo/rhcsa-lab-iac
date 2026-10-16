# Dominio 3 / users_groups: grupo com GID. Params: GRP GIDN
ID=dyn-group-create
do_start() {
    getent group "$GRP" &>/dev/null && groupdel "$GRP"
    getent group "$GIDN" >/dev/null && { echo "ERRO: o GID $GIDN ja esta em uso; rode o lab start de novo"; exit 1; }
    echo "o grupo $GRP nao existe."
}
do_grade() {
    getent group "$GRP" &>/dev/null; check $? "o grupo $GRP existe"
    [ "$(getent group "$GRP" | cut -d: -f3)" = "$GIDN" ]; check $? "o GID de $GRP e $GIDN (atual: $(getent group "$GRP" | cut -d: -f3))"
}
do_finish() { getent group "$GRP" &>/dev/null && groupdel "$GRP"; echo "limpeza: grupo $GRP removido."; }
run "$@"
