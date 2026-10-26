#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

URL=$(flatpak remotes --system --columns=name,url 2>/dev/null | awk '$1=="examrepo"{print $2}')
[ -n "$URL" ]; check $? "remote de sistema examrepo configurado"
echo "$URL" | grep -q '^http://flatpak\.lab\.example\.com:8091/\?$'
check $? "examrepo aponta para http://flatpak.lab.example.com:8091/ (atual: ${URL:-nenhuma})"

flatpak info --system com.vscodium.codium &>/dev/null
check $? "com.vscodium.codium instalado em nivel de sistema"
ORIGEM=$(flatpak info --system -o com.vscodium.codium 2>/dev/null)
[ "$ORIGEM" = "examrepo" ]; check $? "com.vscodium.codium instalado a partir do examrepo (origem atual: ${ORIGEM:-nenhuma})"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
