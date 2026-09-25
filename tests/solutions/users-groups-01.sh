#!/bin/bash
# Solução de referência para users-groups-01 (host: servera). Idempotente.
set -euo pipefail

getent group equipe-suporte >/dev/null || groupadd equipe-suporte

if ! id ana >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G equipe-suporte ana
else
  usermod -s /bin/bash -G equipe-suporte ana
fi
chage -M 90 ana

if ! id bruno >/dev/null 2>&1; then
  useradd -m -s /sbin/nologin bruno
else
  usermod -s /sbin/nologin bruno
fi

echo "users-groups-01: solução aplicada em $(hostname -s)."
