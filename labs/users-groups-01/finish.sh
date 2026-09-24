#!/bin/bash
# Ação inversa explícita do start.sh/das ações do estudante -- nunca
# reinvoca start.sh (start é idempotente e recriaria o estado em vez de
# removê-lo, anti-padrão já descoberto em produção real).
set -uo pipefail

userdel -r ana >/dev/null 2>&1 || true
userdel -r bruno >/dev/null 2>&1 || true
groupdel equipe-suporte >/dev/null 2>&1 || true

echo "Ambiente de 'users-groups-01' limpo em $(hostname -s)."
exit 0
