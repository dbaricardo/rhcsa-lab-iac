# Imagem golden: como e por que é construída assim

A imagem `rhel10-rhcsa-base` é o disco base das 3 VMs. É gerada uma vez
por `make build-image` (`scripts/build-image.sh`) a partir da sua ISO RHEL
10, e o Terraform cria cada VM como um clone copy-on-write dela.

## O fluxo

1. **Chave SSH:** na primeira vez, gera `output/student_key` (ed25519). A
   chave pública entra na imagem; a privada é usada pelo Ansible e pelos
   atalhos `make ssh-*`.
2. **Kickstart:** `kickstart/ks.cfg.tpl` é renderizado com `envsubst`,
   restrito a três variáveis (ver
   [Referência](../reference/configuracao.md#placeholders-do-kickstart-kickstartkscfgtpl)).
   A senha entra só como hash SHA-512. O `ks.cfg` final fica em `output/`,
   fora do git.
3. **Instalação desassistida:** `virt-install` boota a ISO com o kickstart
   injetado no initrd (`--initrd-inject`), sem interação.
4. **Fim determinístico:** o kickstart termina com `poweroff` e o script
   espera o domínio desligar (`--wait -1 --noreboot`).
5. **Sysprep offline:** `image/finalize.sh` roda via `virt-customize`:
   remove chaves SSH de host, limpa logs (inclusive `anaconda-ks.cfg`, que
   guarda o hash da senha) e corrige contextos SELinux.
6. **Publicação atômica:** instala em `<imagem>.qcow2.partial` e só renomeia
   no fim. Um build interrompido nunca deixa uma imagem pela metade com o
   nome final — e o `Makefile` decide se precisa construir pela existência
   desse arquivo.

## O que o kickstart faz

- **Rede por DHCP.** O IP fixo de cada VM vem de uma reserva DHCP na rede
  libvirt do Terraform; a imagem não conhece a topologia e pode ser clonada
  três vezes.
- **Particiona só o disco de instalação** (`autopart --type=lvm
  --fstype=xfs`). Os discos extra da `serverb` são anexados depois, sempre
  brutos.
- **Cria o `student`** com sudo sem senha e a chave SSH; `root` fica
  bloqueado por senha (`rootpw --lock`), como no exame.
- **`%post`:** importa a 4ª chave GPG do RHEL 10, habilita serviços base e
  zera `/etc/machine-id` (cada clone gera o seu).
- **Não registra a subscription.** Ver
  [Arquitetura](arquitetura.md#subscription-e-modo-offline).

## Decisões

- **Sem Packer:** o `virt-install` já é necessário para a instalação
  desassistida; usar Packer só acrescentaria uma ferramenta para instalar e
  aprender, sem ganho de determinismo.
- **BIOS (SeaBIOS), q35:** precisa ser o mesmo firmware e tipo de máquina
  dos domínios do Terraform, senão a imagem não dá boot nas VMs. Por que
  não passar `--boot firmware=bios`:
  [Problemas conhecidos](problemas-conhecidos.md#firmware-bios-no-rhelrocky-10).
- **`--noreboot` + `undefine` explícito:** sem eles, o `virt-install`
  reiniciava o domínio após o `poweroff`, e o domínio ainda segurava o lock
  do qcow2 quando o `virt-customize` tentava abri-lo.
- **`LIBVIRT_DEFAULT_URI=qemu:///system`:** sem isso, rodando como usuário
  comum, `virsh`/`virt-install` podem cair em `qemu:///session`, com rede e
  pool diferentes dos que o Terraform usa.

## Inspecionar o kickstart sem rodar o build

```bash
export STUDENT_USER=student STUDENT_SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"
export STUDENT_PASSWORD_HASH="$(openssl passwd -6 'senha-de-teste')"
envsubst '${STUDENT_USER} ${STUDENT_PASSWORD_HASH} ${STUDENT_SSH_PUBKEY}' \
  < kickstart/ks.cfg.tpl
```
