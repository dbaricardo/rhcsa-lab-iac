#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

ls /home/remoteuser2 &>/dev/null
mount | grep 'remoteuser2' | grep -q nfs
check $? "mount NFS ativo relacionado a remoteuser2 (autofs disparou em /home/remoteuser2)"

mount | grep 'remoteuser2' | grep -Eq '192[.]168[.]56[.]10|workstation'
check $? "mount vem de workstation.lab.example.com (192.168.56.10)"

testfile="/home/remoteuser2/.examsim12-write-test-$$"
runuser -u remoteuser2 -- touch "$testfile" 2>/dev/null
[ -f "$testfile" ]; check $? "remoteuser2 consegue gravar no diretorio automontado"
runuser -u remoteuser2 -- rm -f "$testfile" 2>/dev/null

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
