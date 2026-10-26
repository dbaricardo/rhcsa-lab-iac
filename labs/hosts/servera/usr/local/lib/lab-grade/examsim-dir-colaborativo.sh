#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

[ -d /common/admin ]; check $? "/common/admin existe"

if [ -d /common/admin ]; then
    grp=$(stat -c %G /common/admin)
    [ "$grp" = sysadmin ]; check $? "grupo de /common/admin e sysadmin (atual: $grp)"

    perm=$(stat -c %a /common/admin)
    [ "$perm" = "2770" ]; check $? "permissao de /common/admin e 2770 (atual: $perm)"

    tmpuser=examsim6tester
    id "$tmpuser" &>/dev/null || useradd -G sysadmin -M "$tmpuser"
    marker="/common/admin/.teste-heranca-$$"
    su - "$tmpuser" -c "touch $marker" 2>/dev/null
    if [ -f "$marker" ]; then
        gnew=$(stat -c %G "$marker")
        [ "$gnew" = sysadmin ]; check $? "arquivo novo herda grupo sysadmin (SGID funcionando, atual: $gnew)"
        rm -f "$marker"
    else
        echo "FALHOU: $tmpuser (membro de sysadmin) nao conseguiu criar arquivo em /common/admin"
        FAIL=1
    fi
    userdel "$tmpuser" 2>/dev/null
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
