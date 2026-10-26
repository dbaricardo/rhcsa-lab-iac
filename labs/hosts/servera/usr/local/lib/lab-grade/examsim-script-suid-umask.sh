#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

[ -x /usr/local/bin/newsearch ]; check $? "/usr/local/bin/newsearch existe e e executavel"

if [ -x /usr/local/bin/newsearch ]; then
    /usr/local/bin/newsearch &>/dev/null
    [ -f /root/myoutput ]; check $? "/root/myoutput foi gerado ao rodar newsearch"

    if [ -f /root/myoutput ]; then
        referencia=$(find /usr -type f -perm -4000 -size +30k -size -50k 2>/dev/null | sort)
        atual=$(sort /root/myoutput 2>/dev/null)
        [ "$referencia" = "$atual" ]
        check $? "/root/myoutput bate com a busca de referencia (SUID, 30k-50k, sob /usr)"
    fi
fi

if id alex &>/dev/null; then
    umask_alex=$(su - alex -c 'umask' 2>/dev/null | tr -d '[:space:]')
    case "$umask_alex" in
        0222|222) check 0 "umask padrao de alex e 0222 (atual: $umask_alex)" ;;
        *) check 1 "umask padrao de alex e 0222 (atual: $umask_alex)" ;;
    esac

    # Staging area criada por root (nao entra no teste de umask) -- dentro
    # dela o alex cria UM nivel (mkdir simples, sem -p: o -p do GNU coreutils
    # forca bits extras u+wx nos diretorios intermediarios e mascara o umask).
    testdir=/tmp/examsim14test
    rm -rf "$testdir"
    mkdir -p "$testdir"
    chown alex:alex "$testdir"
    chmod 777 "$testdir"
    su - alex -c "cd $testdir && mkdir novodir && touch novoarquivo" &>/dev/null
    permd=$(stat -c %a "$testdir/novodir" 2>/dev/null)
    permf=$(stat -c %a "$testdir/novoarquivo" 2>/dev/null)
    [ "$permd" = "555" ]; check $? "diretorio novo criado por alex fica r-xr-xr-x (atual: $permd)"
    [ "$permf" = "444" ]; check $? "arquivo novo criado por alex fica r--r--r-- (atual: $permf)"
    rm -rf "$testdir"
else
    echo "FALHOU: usuario alex nao existe"
    FAIL=1
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
