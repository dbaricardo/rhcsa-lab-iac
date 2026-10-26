# Referência: catálogo de exercícios

Fonte: `labs/catalog.json` (27 entradas, escrito à mão, igual ao
`catalog.json` do lab do homelab; `make catalog` só valida). `lab list` na
workstation mostra os mesmos ids. Todos são executados **a partir da
workstation** (`lab start|grade|finish <id>`); a coluna Host diz onde
resolver.

## Provas orquestradas (`number` 0)

| Id | Título | Hosts | Limite | Observação |
|---|---|---|---|---|
| `examsim-full` | Prova completa (24 questões) | servera, serverb, workstation | 180 min | Questões fixas; `grade` recusado; nota só no `finish` (aprovação 17/24) |
| `examsim-dinamico` | Exame dinâmico (24 questões sorteadas) | servera, serverb, workstation | 180 min | Sorteio de `labs/dyn/pool.json` (166 tarefas, ≥ 2 por domínio); `LAB_SEED=<n>` reproduz; nota no `finish` |

## Exercícios avulsos

| # | Id | Título | Host | Resolver por |
|---|---|---|---|---|
| 1 | `examsim-flatpak` | Flatpak: remote e aplicação | servera | ssh |
| 2 | `examsim-network` | Rede e hostname | servera | ssh |
| 3 | `examsim-repo-node1` | Repositórios · servera | servera | ssh |
| 4 | `examsim-selinux-httpd` | HTTP e SELinux | servera | ssh |
| 5 | `examsim-grupos` | Usuários e grupos | servera | ssh |
| 6 | `examsim-dir-colaborativo` | Diretório colaborativo | servera | ssh |
| 7 | `examsim-cron` | Agendamentos com cron | servera | ssh |
| 8 | `examsim-backup` | Backup compactado | servera | ssh |
| 9 | `examsim-ntp` | Sincronização de horário | servera | ssh |
| 10 | `examsim-find-simone` | Arquivos de Simone | servera | ssh |
| 11 | `examsim-find-strato` | Busca por conteúdo | servera | ssh |
| 12 | `examsim-autofs-remoteuser2` | NFS e automount | servera (+ workstation exporta) | ssh |
| 13 | `examsim-user-barry` | Usuário com UID fixo | servera | ssh |
| 14 | `examsim-script-suid-umask` | Script e umask | servera | ssh |
| 15 | `examsim-timer-acl` | Timer systemd e ACL | servera | ssh |
| 16 | `examsim-rootpw-recover-node2` | Recuperação de root | serverb | **console** |
| 17 | `examsim-repo-node2` | Repositórios · serverb | serverb | ssh |
| 18 | `examsim-tuned` | Perfil de desempenho | serverb | ssh |
| 19 | `examsim-swap` | Swap persistente | serverb | ssh |
| 20 | `examsim-lvm-mydatabase` | LVM para database | serverb | ssh |
| 21 | `examsim-script-args` | Shell script com argumentos | servera | ssh |
| 22 | `examsim-lvm-resize-home` | Redimensionar LV home | serverb | ssh |
| 23 | `examsim-tuned-servera` | Instalar e ativar tuned | servera | ssh |
| 24 | `examsim-vgextend` | Estender VG e LV (vgextend) | serverb | ssh |
| 25 | `examsim-treino-storage` | Treino cronometrado: swap + LVM + timer | serverb | ssh (meta 10 min) |

## Dependências de infraestrutura

| Exercícios | Precisam de |
|---|---|
| `examsim-repo-node1/2`, `examsim-tuned-servera`, `examsim-timer-acl`, `dyn-repo-*` | mirror `content.example.com:8091` (role `classroom`, montado da ISO) |
| `examsim-flatpak`, `dyn-flatpak-*` | OSTree `myrepo` (`FLATPAK_MIRROR_ENABLED=true`, internet no deploy) |
| `examsim-ntp` | chrony da workstation (`classroom.example.com`) |
| `examsim-network` | 2ª NIC `ens19` da servera |
| storage/LVM/swap da serverb | discos de 6 e 1 GiB (SCSI) e 2/3 GiB (virtio) |
| `examsim-rootpw-recover-node2` | console: `virsh console rhcsa-lab-serverb` no host |

## Principais Conclusões

- 25 exercícios avulsos + 2 provas orquestradas, iguais ao homelab.
- Avisos: `examsim-vgextend` e `examsim-treino-storage` zeram o disco de
  6 GiB da serverb; não rode durante o `examsim-full`.
- Repos e flatpak dependem do `classroom` na workstation.
