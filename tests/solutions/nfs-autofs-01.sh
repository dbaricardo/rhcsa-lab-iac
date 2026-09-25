#!/bin/bash
# Solução de referência para nfs-autofs-01 (hosts: servera, serverb).
# Detecta o host via hostname -s, igual ao próprio start.sh/grade.sh do
# exercício. Rodar em servera primeiro, depois em serverb (ver README em
# tests/solutions/).
set -euo pipefail

host="$(hostname -s)"

case "$host" in
  servera)
    mkdir -p /export/dados-equipe
    chmod 0755 /export/dados-equipe
    [ -f /export/dados-equipe/leia-me.txt ] \
      || echo "conteúdo de exemplo" > /export/dados-equipe/leia-me.txt

    grep -q '/export/dados-equipe' /etc/exports 2>/dev/null \
      || echo '/export/dados-equipe *(ro,sync,no_subtree_check)' >> /etc/exports
    exportfs -ra

    systemctl enable --now nfs-server

    # Sem isso, serverb nunca consegue montar de verdade -- firewalld
    # bloqueia o RPC/NFS por padrão (ver instructions do exercício).
    if systemctl is-active --quiet firewalld; then
      firewall-cmd --permanent --add-service=nfs >/dev/null
      firewall-cmd --permanent --add-service=rpc-bind >/dev/null
      firewall-cmd --permanent --add-service=mountd >/dev/null
      firewall-cmd --reload >/dev/null
    fi
    ;;
  serverb)
    mkdir -p /mnt/dados-equipe
    if ! grep -q '/mnt/dados-equipe' /etc/auto.master 2>/dev/null; then
      echo '/mnt /etc/auto.dados-equipe' >> /etc/auto.master
    fi
    cat > /etc/auto.dados-equipe <<'EOF'
dados-equipe -fstype=nfs,ro servera:/export/dados-equipe
EOF
    systemctl enable --now autofs
    systemctl restart autofs
    ;;
  *)
    echo "nfs-autofs-01: host desconhecido '$host'" >&2
    exit 2
    ;;
esac

echo "nfs-autofs-01: solução aplicada em ${host}."
