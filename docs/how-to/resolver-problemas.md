# Como resolver problemas comuns

Sintoma → o que fazer. Assume que você já fez um deploy pelo
[tutorial](../tutorials/primeiro-lab-fim-a-fim.md). Para entender por que
esses problemas existem, ver
[Problemas conhecidos e mitigações](../explanation/problemas-conhecidos.md).

Primeiro passo para qualquer falha: `make check-env`. Ele lista todos os
problemas de ambiente de uma vez e diz como corrigir cada um.

## `make provision` para dizendo que a VM "não está registrada"

1. Preencha `RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY` no `.env` (gere em
   <https://console.redhat.com/insights/connector/activation-keys>).
2. Rode `make provision` de novo.

Alternativa sem mexer no `.env` — registre cada VM à mão e reaplique:

```bash
for h in workstation servera serverb; do
  bash scripts/lab-ssh.sh "$h" \
    'sudo subscription-manager register --org=<ORG_ID> --activationkey=<ACTIVATION_KEY>'
done
make provision
```

Sem conta Red Hat: [use o modo offline](deploy-offline.md).

## `subscription-manager register` falha por limite de sistemas

A subscription gratuita tem limite de sistemas simultâneos, e VMs já
destruídas continuam ocupando vaga até serem removidas.

1. Acesse <https://console.redhat.com> → **Inventory** → **Systems**.
2. Remova os sistemas `workstation`/`servera`/`serverb` de deploys antigos.
3. Rode `make provision` de novo.

Para evitar na próxima vez, desregistre antes de destruir — ver
[Destruir e recriar o lab](operar-o-lab.md#destruir-e-recriar-o-lab).

## `make build-image` falha no fim com "Cannot access storage file... Permission denied"

O processo `qemu` não consegue atravessar algum diretório até o disco de
build ou a ISO (comum quando o repositório está em `/root` ou num `$HOME`
sem `o+x`).

1. Rode `make check-env` — ele aponta exatamente qual diretório bloqueia.
2. Libere a busca para o usuário `qemu` nesse diretório (repita para cada
   pai apontado):

   ```bash
   sudo setfacl -m u:qemu:--x /caminho/do/diretorio
   ```

3. Rode `make build-image` de novo.

## `make build-image` falha com "Unable to find 'bios' firmware"

O `scripts/build-image.sh` foi alterado para passar `--boot firmware=bios`.
Remova essa opção: o script deve passar só `--machine q35`. Detalhes em
[Problemas conhecidos](../explanation/problemas-conhecidos.md#firmware-bios-no-rhelrocky-10).

## `make infra` falha com "video model 'cirrus'"

O `terraform/main.tf` foi alterado. Restaure `video { type = "virtio" }` e
`machine = "q35"` no `libvirt_domain`.

## `make infra` reclama que algo "already exists"

Sobrou um domínio, volume ou rede de um deploy interrompido (Ctrl+C, queda
de energia).

1. Tente `make destroy` — remove tudo que está no estado do Terraform.
2. Se o estado se perdeu (`terraform/terraform.tfstate` apagado), limpe à
   mão:

   ```bash
   for d in $(virsh -c qemu:///system list --all --name | grep '^rhcsa-lab-'); do
     virsh -c qemu:///system destroy "$d"; virsh -c qemu:///system undefine "$d"
   done
   for v in $(virsh -c qemu:///system vol-list default | awk '/rhcsa-lab-/ {print $1}'); do
     virsh -c qemu:///system vol-delete "$v" default
   done
   virsh -c qemu:///system net-destroy rhcsa_lab; virsh -c qemu:///system net-undefine rhcsa_lab
   ```

3. Rode `make deploy` (ou `make infra`) de novo.

## Modo offline falha com "BaseOS/repodata não encontrado"

`RHEL_ISO_PATH` aponta para a boot ISO (netinstall). Baixe a **DVD ISO**
completa, ajuste o `.env` e rode `make check-env`.

## Uma VM sobe sem rede

1. Entre pelo console: `virsh -c qemu:///system console rhcsa-lab-<vm>`.
2. Procure AVCs no kernel (não no `ausearch`): `dmesg | grep -i avc`.
3. Se aparecer `unlabeled_t`, corrija e reinicie:

   ```bash
   sudo restorecon -Rv /etc && sudo reboot
   ```

4. Para não repetir, reconstrua a imagem (`make build-image`).

## `dnf` falha com "SIGNATURE: NOT OK"

Importe a 4ª chave de release do RHEL 10 na VM afetada:

```bash
sudo rpm --import https://security.access.redhat.com/data/6afedf8f.txt
```

O kickstart e o role `common` já fazem isso. Se aconteceu, a imagem veio
de fora do `build-image.sh` — rode `make provision` para reaplicar.

## `lab start storage-lvm-01` não encontra o disco de 6 GB

O disco ficou com partições de uma tentativa anterior.

1. Rode `lab finish storage-lvm-01` (e `lab finish filesystems-01`, se
   usou) na `workstation` — o `finish` limpa as partições.
2. Rode `lab start storage-lvm-01` de novo.

## Um exercício passa ou falha "sozinho"

Estado sobrou de outro exercício. Rode `lab finish <id>` do exercício
anterior antes de começar o próximo. Se o problema for no próprio
exercício, ver [Criar um exercício](criar-exercicio.md) — o `finish.sh`
dele precisa reverter a configuração compartilhada.
