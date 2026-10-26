#!/bin/bash
# Executa casos reais do script do aluno (stdout, stderr e codigo de saida).
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }
S=/usr/local/bin/userinfo
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

roda() {  # roda <nome> args... -> $T/<nome>.out, $T/<nome>.err, $T/<nome>.rc
    local n=$1; shift
    timeout 10 "$S" "$@" >"$T/$n.out" 2>"$T/$n.err" </dev/null
    echo $? >"$T/$n.rc"
}

[ -f "$S" ]; check $? "$S existe"
[ -x "$S" ]; check $? "$S e executavel"
head -1 "$S" 2>/dev/null | grep -q '^#!'; check $? "$S comeca com shebang (#!)"

if [ -x "$S" ]; then
    roda vazio
    [ "$(cat "$T/vazio.rc")" = 1 ] && [ ! -s "$T/vazio.out" ] && [ -s "$T/vazio.err" ]
    check $? "sem argumentos: mensagem de uso no stderr, nada no stdout, saida 1 (atual: $(cat "$T/vazio.rc"))"

    roda um root
    [ "$(cat "$T/um.rc")" = 0 ] && [ "$(cat "$T/um.out")" = "root:0:/root" ]
    check $? "userinfo root imprime root:0:/root e sai 0"

    roda dois root nobody
    [ "$(cat "$T/dois.rc")" = 0 ] && [ "$(cat "$T/dois.out")" = "$(printf 'root:0:/root\nnobody:65534:/')" ]
    check $? "userinfo root nobody imprime uma linha por usuario, na ordem, e sai 0"

    roda misto root examsim21-naoexiste nobody
    [ "$(cat "$T/misto.out")" = "$(printf 'root:0:/root\nnobody:65534:/')" ] \
        && grep -q '^examsim21-naoexiste: inexistente$' "$T/misto.err"
    check $? "usuario inexistente vai para o stderr como '<user>: inexistente' e o laco continua"
    [ "$(cat "$T/misto.rc")" = 2 ]
    check $? "com algum usuario inexistente a saida final e 2 (atual: $(cat "$T/misto.rc"))"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
