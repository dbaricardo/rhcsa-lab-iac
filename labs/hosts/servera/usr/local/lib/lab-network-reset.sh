#!/bin/bash
# Restaura a NIC dedicada do examsim-network para um estado neutro.
# O perfil-base inativo impede que o NetworkManager crie um perfil DHCP
# automático, mas mantém ens19 gerenciada para o aluno criar/ativar sua
# própria conexão manual com nmcli ou nmtui.
set -euo pipefail

reset_examsim_network() {
    local uuid device

    hostnamectl set-hostname servera.lab.example.com
    nmcli device set ens19 managed yes
    nmcli device set ens19 autoconnect no
    nmcli device disconnect ens19 >/dev/null 2>&1 || true

    # UUID é seguro mesmo quando o nome do perfil contém espaços. O campo
    # connection.interface-name continua disponível para perfis inativos,
    # ao contrário do campo DEVICE da listagem resumida.
    while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        device=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
        [ "$device" = "ens19" ] || continue
        nmcli connection delete uuid "$uuid" >/dev/null
    done < <(nmcli -t -f UUID connection show)

    nmcli connection add type ethernet ifname ens19 \
        con-name examsim-ens19-reset \
        connection.autoconnect no \
        ipv4.method disabled \
        ipv6.method disabled >/dev/null

    nmcli device set ens19 autoconnect yes
    nmcli device disconnect ens19 >/dev/null 2>&1 || true

    # A remoção do endereço no kernel pode convergir depois do retorno do
    # nmcli. Aguarda no máximo 5 s e falha de forma explícita se persistir.
    local attempt
    for attempt in {1..20}; do
        [ -z "$(nmcli -g IP4.ADDRESS device show ens19 2>/dev/null)" ] && break
        sleep 0.25
    done
    if [ -n "$(nmcli -g IP4.ADDRESS device show ens19 2>/dev/null)" ]; then
        echo "ERRO: ens19 ainda possui IPv4 após o reset." >&2
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    reset_examsim_network
fi
