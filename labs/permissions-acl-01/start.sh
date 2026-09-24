#!/bin/bash
# Idempotente: garante que a usuária 'carla' exista (ela é o alvo da ACL que
# o estudante vai configurar, não faz parte do que ele precisa criar).
set -euo pipefail

if ! id carla >/dev/null 2>&1; then
  useradd -m -s /sbin/nologin carla
fi

echo "Ambiente pronto para 'permissions-acl-01' em $(hostname -s)."
echo "Usuária 'carla' disponível. Crie o grupo, o diretório e as ACLs solicitadas, depois rode: lab grade permissions-acl-01"
