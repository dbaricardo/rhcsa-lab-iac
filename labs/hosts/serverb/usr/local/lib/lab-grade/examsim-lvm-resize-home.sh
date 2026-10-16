#!/bin/bash
set -u
# VG parametrizavel: na prova completa (examsim-full) o LV fica em vg_home
# para nao colidir com o myvg da questao 20. Avulso continua myvg.
VG=${EXAMSIM_HOME_VG:-myvg}
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

lvs "$VG/home" &>/dev/null; check $? "LV home existe em $VG"

if lvs "$VG/home" &>/dev/null; then
    size_mb=$(lvs --noheadings -o lv_size --units m "$VG/home" 2>/dev/null | tr -d ' m')
    size_mb_int=${size_mb%.*}
    [ -n "$size_mb_int" ] && [ "$size_mb_int" -ge 145 ] && [ "$size_mb_int" -le 155 ]
    check $? "LV home entre 145-155MB / ~38 extents (atual: ${size_mb}M)"
fi

mountpoint -q /mnt/examsim-home; check $? "/mnt/examsim-home ainda montado"
[ -f /mnt/examsim-home/teste-examsim22.txt ]; check $? "arquivo de teste sobreviveu ao resize (dado preservado)"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
