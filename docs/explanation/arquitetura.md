# Arquitetura do lab

Como as peças se encaixam e por que foram desenhadas assim. Para os
valores exatos (IPs, portas, variáveis), ver a
[Referência de configuração](../reference/configuracao.md).

## Objetivo de design: idêntico ao lab do homelab

Desde 2026-10 o repositório reproduz **o mesmo lab RHCSA** que roda no
homelab do autor (3 VMs Proxmox): as mesmas 24 questões avulsas
`examsim-*` + o treino `examsim-treino-storage`, a prova completa
`examsim-full`, o exame dinâmico `examsim-dinamico` (pool de 166 tarefas),
o mesmo dashboard e o mesmo comando `lab`. Os scripts são cópias dos que
rodam lá; só muda o que é inevitável por estar em outra rede:

| Homelab | Aqui | Papel |
|---|---|---|
| `192.168.10.132` / `.135` / `.137` | `192.168.56.20` / `.30` / `.10` | servera / serverb / workstation |
| `192.168.10.19` (LXC "classroom") | `192.168.56.10` (a própria workstation) | mirror `:8091`, flatpak, NTP |
| `192.168.10.1` e DNS `192.168.10.30` | `192.168.56.1` (host libvirt) | gateway e "DNS" |
| `192.168.10.91` | `192.168.56.91` | IP de prática da `ens19` (servera) |
| `qm reboot`, noVNC | `virsh reboot`, `virsh console` | textos dos avisos |

Nomes que **não** mudam: `servera|serverb|workstation.lab.example.com`,
`content.example.com`, `classroom.example.com`, `repo.example.com`,
`flatpak.lab.example.com`, porta `8091`, NICs `ens18`/`ens19`.

## Topologia

```
                     rede NAT libvirt "rhcsa_lab" 192.168.56.0/24
                     gateway/DNS 192.168.56.1 (host) · ISO em :8080 no deploy
   ┌───────────────────────────────┐  SSH root   ┌──────────────────────────────┐
   │ workstation  192.168.56.10    │────────────►│ servera  192.168.56.20       │
   │  lab (lab_wrapper.py)         │             │  ens18 + ens19 (sem IP)      │
   │  rhcsa-lab-original           │             │  vda 2 GiB, vdb 3 GiB        │
   │  lab-full/ · lab-dyn/         │             │  lab + lab-scripts/grade/... │
   │  dashboard :8421 (SQLite)     │  SSH root   ├──────────────────────────────┤
   │  "classroom": nginx :8091     │────────────►│ serverb  192.168.56.30       │
   │    content/classroom/repo/    │             │  sdb 6 GiB, sdc 1 GiB (SCSI) │
   │    flatpak.lab.example.com    │             │  vda 2 GiB, vdb 3 GiB        │
   │  chrony (NTP do lab), NFS     │             │  lab + lab-full/...-serverb  │
   └───────────────────────────────┘             └──────────────────────────────┘
        disco do SO: SCSI sda 20 GiB nas 3 VMs (BIOS, como no Proxmox)
```

- Toda a topologia (IPs, MACs, NICs, discos, porta do dashboard e do
  classroom) vem de `machines.yaml`, lido pelo Terraform
  (`yamldecode`) e pelo Ansible (`group_vars/all.yml`).
- **Nomes de NIC iguais ao Proxmox:** o Terraform fixa os MACs; o role
  `common` grava arquivos systemd `.link` (MAC → `ens18`/`ens19`),
  regenera o initramfs e reinicia a VM uma vez. O IP não muda (reserva DHCP
  e perfil NM estático `ens18` usam o mesmo endereço).
- **Discos achados por tamanho, nunca por nome:** os exercícios e o
  `lab-common.sh` procuram 1 GiB, 6 GiB, 2 GiB e 3 GiB exatos; a ordem
  `sdb`/`sdc`/`vda`/`vdb` já inverteu entre boots em produção.

## Fluxo de deploy

```
make deploy | deploy-offline
  ├─ build-image   virt-install + kickstart (disco SCSI) → finalize.sh
  ├─ infra         terraform apply: rede, volumes CoW, discos, 3 domínios,
  │                output/inventory.yml
  └─ provision     scripts/offline-repo.sh serve a ISO em 192.168.56.1:8080
                   ansible-playbook ansible/site.yml (7 plays, abaixo)
```

Ordem das plays em `ansible/site.yml`:

0. **all** — espera SSH e fixa o hostname FQDN.
1. **all** — `common` (usuário, subscription ou repo da ISO, rede
   `ens18`/`ens19`, `/etc/hosts`, paridade de pacotes com o homelab,
   senha de root opcional, SELinux, firewalld) + `ssh_crosshost` (chave do
   `student` da workstation no `root` das 3 VMs).
2. **workstation** — `classroom` (nginx `:8091`, mirror parcial
   BaseOS/AppStream tirado da ISO, `/timer-repo` com o RPM `logger`,
   OSTree `myrepo` do Flathub, NTP).
3. **servera** — `servera` + `lab_common`.
4. **serverb** — `serverb` + `lab_common`.
5. **workstation** — `dashboard`, `workstation` (wrapper `lab`,
   `rhcsa-lab-original`, `lab-full/`), `lab_common` (lado NFS do autofs),
   `lab_dyn` (motor do exame dinâmico) e `ai_review` (opcional).
6. **all** — **lockdown**: remove os repos do deploy, desabilita os da
   subscription (sem `unregister`) e confere que **nenhum** repo ficou
   habilitado — estado igual ao do homelab, onde os exercícios de
   repositório partem do zero.

## Classroom dentro da workstation

No homelab o mirror de pacotes, o repositório flatpak e o NTP rodam numa
LXC separada. Aqui isso viraria uma 4ª VM só para servir arquivos, então o
role `classroom` coloca tudo na workstation, com os **mesmos nomes e
caminhos** (`content.example.com:8091/rhel10.0/x86_64/dvd/{BaseOS,AppStream}`,
`/timer-repo`, `flatpak.lab.example.com:8091/myrepo.flatpakrepo`):

- O mirror de RPMs é **parcial**: os mesmos ~50 nomes de pacote do mirror
  do homelab, baixados da ISO do usuário (nunca redistribuídos).
- O OSTree `myrepo` (VSCodium, Obsidian e runtimes, ~1,6 GB) é montado do
  Flathub no deploy; desligável com `FLATPAK_MIRROR_ENABLED=false`.
- Lição do homelab preservada: o `ostree pull` deixa os refs só no
  namespace do remote, e o `flatpak build-update-repo` não os indexa —
  cada ref ganha um alias em `refs/heads/` antes do summary.

## Comando `lab`: três camadas

```
student@workstation$ lab start examsim-cron
  └─ /usr/local/bin/lab                 lab_wrapper.py: registra no SQLite do
                                        dashboard, dispara a revisão por IA
     └─ /usr/local/libexec/rhcsa-lab-original
           dispatcher: decide o(s) host(s) e a ordem
           └─ ssh root@servera "lab start examsim-cron"
                 └─ /usr/local/bin/lab (local) → lab-scripts/examsim-cron.sh
```

- O wrapper é transparente: repassa saída e código de retorno.
- `examsim-full` e `examsim-dinamico` não vão a um host só: o dispatcher
  chama `lab-full/examsim-full.sh` ou `lab-dyn/examsim-dinamico.sh`, que
  preparam as 24 questões em servera, serverb e workstation e só corrigem no
  `finish` (nota X/24, aprovação com 17).
- O exame dinâmico sorteia de `pool.json` (24 legadas + 142 portadas, mínimo
  de 2 por domínio); `LAB_SEED=<n>` reproduz uma prova. As tarefas portadas
  vão por SSH (base64 em `bash -c`), não ficam instaladas em servera/serverb.

## Dashboard

Serviço systemd `rhcsa-lab-dashboard` na workstation (`backend.py`,
`http.server` sem framework, porta 8421), só leitura: `GET /`,
`/api/state`, `/healthz`. Lê o SQLite que o wrapper grava e os manifestos
públicos do exame dinâmico em `/var/lib/rhcsa-lab-dashboard/dinamico/`.
Senhas de exercício (`atenorth`) e a `LAB_ROOT_PASSWORD` são mascaradas
nas saídas. Firewalld libera a porta só para `dashboard.allowed_source`.

## Revisão por IA e gravação (opcionais)

Desligadas por padrão. Com `RHCSA_RECORDING_ENABLED=true`, cada login
interativo nas 3 VMs é gravado com `script` em `/var/log/rhcsa-rec`; com
`AI_REVIEW_ENABLED=true` + `AI_REVIEWER`, o `lab finish` envia a transcrição
para um revisor por SSH (`contrib/ai-reviewer/`) e grava o retorno em
`~/examsim-feedback/`. A nota do `lab` nunca espera a revisão.

## Subscription e modo offline

- **Nunca registrar a imagem golden:** as 3 VMs são clones; registrada,
  compartilhariam o mesmo consumer ID (já causou conflito real). O role
  `common` registra **cada VM depois de clonada** com
  `RHSM_ORG_ID`/`RHSM_ACTIVATION_KEY`, ou falha cedo se não houver registro.
- **Modo offline** (`make deploy-offline`): BaseOS/AppStream vêm da ISO
  servida pelo host; serve para testar sem conta Red Hat.
- Nos dois modos a ISO também é servida (`lab_iso_url`) porque é dela que o
  `classroom` tira os RPMs do mirror parcial.

## Por que Terraform + Ansible, sem Vagrant nem Packer

- **Estado explícito:** `make destroy` remove domínios, volumes e rede sem
  sobras (teste T11).
- **Menos peças frágeis:** o `vagrant-libvirt` compila gems nativas e usava
  defaults (`cirrus`, máquina `pc`) que o libvirt do RHEL/Rocky 10 rejeita.
- **Sem Packer:** `virt-install` + kickstart já são necessários; o fluxo
  kickstart → `virt-customize` → qcow2 base é reproduzível sem outro builder.
- **RHEL 10 real:** o exame é aplicado sobre RHEL; há um
  [guia para Rocky Linux](../how-to/usar-rocky-linux.md), sem o mesmo rigor.

## Principais Conclusões

- O repo é uma cópia fiel do lab do homelab; só IPs e textos de
  console/reboot mudam, conforme a tabela acima.
- 3 VMs; o "classroom" e o dashboard são serviços da workstation.
- `lab` = wrapper (registro/IA) → dispatcher → `ssh root@host lab ...`.
- O lockdown final deixa as 3 VMs sem nenhum repositório habilitado.
