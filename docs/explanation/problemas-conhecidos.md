# Problemas conhecidos e mitigações

Bugs reais, encontrados ao montar e usar este tipo de ambiente, que
explicam decisões do código que parecem estranhas à primeira vista. Todos
já estão **mitigados**; esta página existe para que ninguém desfaça uma
mitigação sem saber por que ela está lá.

Se você está diante de um sintoma agora, vá direto para
[Resolver problemas](../how-to/resolver-problemas.md).

## 4ª chave GPG do RHEL 10

**Sintoma:** qualquer `dnf install` falha com `SIGNATURE: NOT OK` numa
instalação limpa.

**Causa:** o RHEL 10.x assina pacotes também com uma **4ª chave de
release**, pós-quântica (key ID `05707a62`), que não vem pré-instalada. Sem
ela, o RPM não valida nenhum pacote novo.

**Mitigação:** o `%post` do `kickstart/ks.cfg.tpl` importa a chave durante
o build da imagem, e o role `common` importa de novo (defesa em
profundidade, para imagens RHEL 10 que não passaram pelo
`build-image.sh`).

## Ordem dos discos não é estável

**Sintoma:** um exercício de storage pega o disco errado depois de um boot.

**Causa:** a ordem `/dev/sdb`, `/dev/sdc` (ou `vdb`, `vdc`) não é garantida
entre boots — já inverteu em produção. O libvirt anexa os discos extra na
ordem declarada, mas o kernel não promete manter essa ordem nos nomes.

**Mitigação:** nenhum script referencia disco por nome. Os helpers de
`lab-common.sh` resolvem o disco **por tamanho**, excluindo o disco do
sistema ([referência](../reference/contrato-exercicios.md#helpers-de-disco-usrlocalliblab-commonsh)).
O role `serverb` faz o mesmo.

## SELinux `unlabeled_t` derruba a rede de VMs clonadas

**Sintoma:** uma VM recém-clonada sobe sem rede e **não** aparece nenhum AVC
no `ausearch`.

**Causa:** o clone pode deixar `/etc/machine-id` ou perfis do
NetworkManager com contexto `unlabeled_t`. Isso derruba o `journald`, que
derruba o `dbus`, que derruba o NetworkManager, em cascata. O AVC só
aparece no `dmesg`: o `ausearch` depende justamente do `auditd`/`journald`
que estão quebrados.

**Mitigação:** `image/finalize.sh` roda `restorecon -Rv /etc` offline (via
`virt-customize`) antes do primeiro boot de qualquer clone; o kickstart zera
`/etc/machine-id` para que cada clone gere o seu; e o role `common` repete
o `restorecon` a cada provisionamento.

## "finish chama start" contamina o próximo exercício

**Sintoma:** depois de `lab finish`, o host fica num estado inesperado, ou o
próximo exercício passa/falha sem motivo.

**Causa:** um `finish.sh` que chamava o `start.sh` para "resetar". O
`start.sh` garante que o estado **exista** — chamá-lo recria o estado em vez
de removê-lo. Aconteceu três vezes antes de virar regra.

**Mitigação:** regra do contrato: `finish.sh` é o inverso explícito do
`start.sh` e reverte configuração compartilhada (`httpd.conf`, portas,
booleans). Ver [Contrato dos exercícios](../reference/contrato-exercicios.md).

## Exercício de LVM "perdia" o disco depois de um `finish` (catálogo antigo, `storage-lvm-01`)

**Sintoma:** após `lab finish storage-lvm-01`, o próximo `lab start` não
achava o disco de 6 GB.

**Causa:** o `finish.sh` antigo apagava só o PV/LV; a tabela de partições
criada pelo estudante ficava. `resolve_disco()` exige disco **cru**, então
o disco nunca mais era considerado livre.

**Mitigação:** o `finish.sh` localiza o disco com `disco_por_tamanho()`
(aceita disco particionado) e roda `wipefs -a` em cada partição e no disco
inteiro. `filesystems-01` segue o mesmo padrão.

## Ordem do `finish` em exercícios multi-host

**Causa:** em `nfs-autofs-01`, limpar o servidor (remover o export) antes do
cliente (desmontar) deixava o cliente pendurado num NFS inexistente.

**Mitigação:** o `lab` roda `finish` na ordem **inversa** de `hosts`. Era
uma regra só documentada; virou código depois de falhar na prática.

## Usuário `qemu` sem acesso ao disco de build

**Sintoma:** `make build-image` instala tudo e só falha no fim, com
`Cannot access storage file ... Permission denied`.

**Causa:** `qemu:///system` roda o domínio como o usuário `qemu`, não como
você — mesmo com `sudo`. Ele precisa de permissão de busca (`x`) em todo
diretório pai do disco e da ISO, e `/root` (ou alguns `$HOME`) não dá.

**Mitigação:** `make check-env` sobe a árvore de diretórios checando o bit
`x` (e ACLs `user:qemu:--x`) e aponta o diretório exato a liberar.

## Vídeo `cirrus` e máquina `pc` não existem mais

**Causa:** o libvirt/QEMU do RHEL/Rocky 10 removeu o modelo de vídeo
`cirrus` (padrão do antigo `vagrant-libvirt`) e marcou a máquina
`pc`/i440fx como obsoleta.

**Mitigação:** `terraform/main.tf` declara `machine = "q35"` e
`video { type = "virtio" }`.

## Firmware BIOS no RHEL/Rocky 10

**Sintoma:** `virt-install` aborta com `Unable to find 'bios' firmware that
is compatible with the current configuration`.

**Causa:** `--boot firmware=bios` pede ao libvirt para *autoselecionar* um
firmware BIOS pelos descritores JSON de `/usr/share/qemu/firmware/`. No
RHEL/Rocky 10 só o `edk2-ovmf` (UEFI) instala descritores; o `seabios` não.
`virsh domcapabilities` lista só `efi`, e a autoseleção de BIOS falha mesmo
com o SeaBIOS instalado.

**Mitigação:** `scripts/build-image.sh` passa `--machine q35` e **não**
passa `--boot`. Sem `<os firmware=...>`, o libvirt usa o SeaBIOS embutido do
QEMU em qualquer distribuição — o mesmo firmware dos domínios do Terraform.
A imagem nasce com partição biosboot e dá boot nas 3 VMs. Trocar só a
imagem para UEFI quebraria o boot das VMs.

## Limite de sistemas da subscription gratuita

**Causa:** a Red Hat Developer Subscription for Individuals limita sistemas
registrados simultâneos. Cada VM se registra com identidade própria
([por quê](arquitetura.md#subscription-e-modo-offline)), então cada ciclo
deploy + destroy consome 3 vagas, que continuam ocupadas até serem
removidas no console.

**Mitigação:** não há como evitar no código sem compartilhar identidade.
O guia [Operar o lab](../how-to/operar-o-lab.md#destruir-e-recriar-o-lab)
desregistra antes do `destroy`, e o modo offline não consome vagas.

## Flathub recusa o `ostree pull` com HTTP 403

**Sintoma:** o role `classroom` falha em "Espelhar codium/Obsidian" com
`While fetching https://dl.flathub.org/repo/objects/...commit: Server
returned HTTP 403`, em todos os refs.

**Causa:** desde 2026-10 o CDN do Flathub bloqueia o User-Agent padrão do
ostree (`libostree/<versão>`); o mesmo objeto vem com 200 para `curl` ou
para o UA do flatpak. O homelab montou o `myrepo` antes disso.

**Mitigação:** `classroom-flatpak-mirror.sh` passa
`--http-header=User-Agent=flatpak/1.16.0` (sobrescrevível por
`FLATHUB_USER_AGENT`). Se voltar a falhar, teste com
`curl -A '<ua>' -o /dev/null -w '%{http_code}' <url-do-objeto>`.

## `dnf` aborta com "Parsing armored OpenPGP packet(s) failed"

**Sintoma:** no deploy do zero, `common : Instalar os pacotes do homelab`
falha de forma intermitente com `RuntimeError: Parsing armored OpenPGP
packet(s) failed` (traceback em `dnf.crypto.retrieve`).

**Causa:** quando um pacote é assinado por uma chave que ainda não está no
keyring do rpm, o dnf importa sozinho o `gpgkey=` do `.repo`, e o parser do
libdnf às vezes falha no `RPM-GPG-KEY-redhat-release` do RHEL 10.

**Mitigação:** `roles/common/tasks/repos.yml` importa a chave com
`rpm --import` antes de qualquer `dnf install`. A `RPM-GPG-KEY-redhat-release-4`
(pós-quântica) é só tentativa: o rpm 4.19 do RHEL 10.0 recusa ("key 1 import
failed").

## Grade de partição GPT via 0 MiB (exame dinâmico)

**Sintoma:** `dyn-part-gpt-create` reprovava "a particao tem ~200 MiB
(atual: 0 MiB)" com a partição certa no disco (2 de 3 provas da seed 1478).

**Causa:** não isolada: fora da prova, 15/15 medições corretas; tuned e
grubby não relêem a tabela. O `blockdev --getsize64` falhava no instante do
grade.

**Mitigação (único desvio do código do homelab):** o grade espera o udev,
tenta de novo por até 5 s e cai no tamanho do sysfs. Depois: 3/3 provas 24/24.
