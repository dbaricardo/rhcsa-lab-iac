# rhcsa-lab-iac

Infraestrutura como código para um laboratório de estudos para o exame
**RHCSA (EX200)** da Red Hat, totalmente reproduzível a partir de uma ISO
RHEL 10 própria: três VMs (`workstation`, `servera`, `serverb`) criadas por
**Terraform** sobre libvirt/KVM e configuradas por **Ansible**, com um
catálogo extensível de exercícios práticos, correção automática e um
dashboard web de acompanhamento. Um comando (`make deploy`) faz tudo.

**Primeira vez aqui? Siga o [tutorial completo](docs/tutorial-fim-a-fim.md)**
— ele assume zero conhecimento prévio deste repositório e cobre cada passo,
do zero até resolver o primeiro exercício.

> Aviso de direitos autorais: este projeto **não contém** nenhum conteúdo do
> material oficial de treinamento da Red Hat. Ver [NOTICE.md](NOTICE.md).

## Pré-requisitos

No host onde as VMs vão rodar (Linux com suporte a KVM):

- **KVM/libvirt** habilitado (`/dev/kvm` presente, virtualização ligada na
  BIOS/UEFI) e o storage pool `default` do libvirt
- **Terraform** ≥ 1.5 (o provider `dmacvicar/libvirt` é baixado sozinho no
  primeiro `make deploy`)
- **virt-install** e **guestfs-tools** (`libguestfs-tools` em Debian/Ubuntu
  e em distribuições mais antigas) para construir a imagem golden
- **Ansible** (`ansible-core`) + a collection em `ansible/requirements.yml`
  (`ansible-galaxy collection install -r ansible/requirements.yml`)
- **python3** (com PyYAML), **envsubst** (pacote `gettext`), **qemu-img**,
  **xorriso**
- **Recursos**: ~8 GB de RAM livres (3 VMs de 2 GB + o host) e ~40 GB de
  disco
- A **ISO oficial do RHEL 10** (DVD, não a boot ISO) baixada da sua própria
  conta Red Hat — este repositório nunca inclui ou redistribui a ISO
- Uma conta **Red Hat Developer Subscription for Individuals** (gratuita),
  com org ID e activation key — ou nada disso, se for usar o modo offline de
  teste (`make deploy-offline`)

Rode `make check-env` para validar tudo isso automaticamente antes de
continuar. Detalhes de como obter a conta/ISO estão no
[tutorial completo](docs/tutorial-fim-a-fim.md).

## Passo a passo resumido

```bash
cp .env.example .env
# edite .env: RHEL_ISO_PATH, STUDENT_PASSWORD, RHSM_ORG_ID, RHSM_ACTIVATION_KEY

make check-env      # valida binários, libvirt, .env
make deploy         # imagem golden (se ainda não existir) + 3 VMs + Ansible
```

`make deploy` encadeia, sem pausa:

1. `make build-image` — instala a imagem golden `rhel10-rhcsa-base` via
   `virt-install` + kickstart (só na primeira vez, ~10 min)
2. `make infra` — `terraform apply`: rede NAT `192.168.56.0/24`, discos e as
   3 VMs, e gera o inventário do Ansible em `output/inventory.yml`
3. `make provision` — Ansible: registra cada VM na subscription, instala os
   pacotes, os exercícios, o dispatcher `lab` e o dashboard

Sem conta Red Hat (só para testar a infraestrutura), use `make deploy-offline`:
os pacotes vêm da própria ISO, sem updates.

Cada etapa também roda sozinha (útil para depurar ou reaplicar só o
Ansible). O Ansible é idempotente: `make provision` pode ser rodado de novo
a qualquer momento.

Depois que o deploy terminar, acesse o dashboard no endereço impresso no
final (por padrão `http://192.168.56.10:8421`) para ver o catálogo de
exercícios e o progresso.

Todo o trabalho com exercícios é feito de dentro da `workstation`:

```bash
make ssh-workstation

lab list                       # lista o catálogo de exercícios
lab start users-groups-01      # prepara o ambiente do exercício
# ... resolva o exercício no host indicado (servera/serverb, ou na própria workstation) ...
lab grade users-groups-01      # avalia e registra o resultado no dashboard
lab finish users-groups-01     # limpa o estado do exercício
```

Para destruir as VMs, os discos e a rede (sem remover a imagem golden já
construída):

```bash
make destroy
```

Lista completa de targets do `Makefile`: `make help`.

## Arquitetura resumida

- **3 VMs**, não 4: o dashboard web (porta 8421) é um **serviço systemd
  dentro da `workstation`**, não uma VM separada — evita o custo de mais uma
  VM só para servir uma página que só faz sentido junto do dispatcher `lab`.
- **Terraform + Ansible, sem Vagrant**: o Terraform (provider
  `dmacvicar/libvirt`) cria e destrói a infraestrutura com estado próprio —
  nada fica para trás depois de um `make destroy` — e o Ansible configura
  tudo dentro das VMs. `machines.yaml` é a única fonte de verdade da
  topologia para os dois.
- **Sem Packer**: a imagem golden `rhel10-rhcsa-base` é construída direto por
  `virt-install` + kickstart (`scripts/build-image.sh`), decisão deliberada para
  reduzir dependências — quem for rodar isto só precisa apontar o caminho de
  uma ISO que já baixou da própria conta Red Hat, sem instalar e aprender
  mais uma ferramenta de build de imagem.
- **RHEL 10 real**, não uma distribuição derivada, porque o objetivo é
  praticar para um exame que é aplicado sobre RHEL de verdade (registro via
  Red Hat Developer Subscription for Individuals, gratuita). Há uma
  [nota sobre fallback com Rocky Linux](docs/rocky-linux-fallback.md), mas
  não é o caminho testado/mantido com o mesmo rigor.
- **Dispatcher `lab` (remoto, na workstation) delega por SSH** para
  `lab-remote` (local, em servera/serverb) — o dispatcher remoto nunca
  executa lógica de exercício localmente; se o host de destino estiver
  inacessível, ele falha explicitamente (código de saída 2) em vez de
  silenciosamente pular a etapa.

Detalhes completos, diagrama da topologia e as decisões de design com o
porquê: [docs/architecture.md](docs/architecture.md).

## Problemas conhecidos

Bugs reais já encontrados em produção (GPG/assinatura de pacotes, enumeração
instável de disco, SELinux `unlabeled_t` pós-clone, limite de sistemas da
subscription gratuita, entre outros), já mitigados no código, mas úteis de
conhecer: [docs/troubleshooting.md](docs/troubleshooting.md).

## Contribuindo com novos exercícios

`labs/` contém um conjunto extensível de exercícios originais, cobrindo os
domínios públicos do blueprint EX200. Para escrever um novo exercício
(estrutura de arquivos, contrato de saída do `grade.sh`, regras não
negociáveis), ver o
[guia de autoria de exercícios](docs/exercises-authoring-guide.md).

## Direitos autorais

Este projeto **não inclui** nenhum trecho do material oficial de treinamento
da Red Hat ("RH199 Rapid Track Student Workbook" ou qualquer outro). Os
exercícios são escritos do zero pelo autor. Ver
[NOTICE.md](NOTICE.md) e [docs/copyright-notice.md](docs/copyright-notice.md)
para o contexto completo.
