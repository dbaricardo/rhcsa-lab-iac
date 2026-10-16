# Referência: catálogo de exercícios

Exercícios em `labs/`, na ordem de `number`. `lab list` na `workstation`
mostra a mesma lista. O catálogo é **fixo**: não há sorteio — cada
exercício é escolhido pelo id em `lab start <id>`.

| # | Id | Host(s) | Domínio EX200 | Título |
|---|---|---|---|---|
| 1 | `users-groups-01` | servera | Create and configure local users and groups | Usuários, grupos e política de senha |
| 2 | `permissions-acl-01` | servera | Manage file permissions, special bits, ACLs | Permissões especiais (SGID) e ACLs em diretório compartilhado |
| 3 | `storage-lvm-01` | serverb | Configure and manage layered storage, LVM | Armazenamento em camadas com LVM (PV/VG/LV) e XFS |
| 4 | `filesystems-01` | serverb | Create simple file systems and manage swap | Partição, filesystem ext4 e swap adicional |
| 5 | `networking-nmcli-01` | servera | Configure networking with nmcli | Perfil de conexão estático com nmcli |
| 6 | `systemd-services-01` | servera | Create and manage systemd units and timers | Unit systemd customizada + timer substituindo cron |
| 7 | `selinux-01` | servera | Manage SELinux contexts, ports and booleans | Contexto SELinux, porta customizada e boolean para um serviço web |
| 8 | `firewalld-01` | servera | Configure firewall settings with firewalld | Serviço e porta customizados persistentes no firewalld |
| 9 | `nfs-autofs-01` | servera, serverb | Manage NFS network file systems | Compartilhamento NFS com automontagem via autofs |
| 10 | `shell-scripting-01` | workstation | Write simple shell scripts | Script bash com validação de argumentos e processamento em loop |

Exercícios de disco (`storage-lvm-01`, `filesystems-01`) usam os discos
extra da `serverb` (6 GB e 1 GB).

Para adicionar um exercício: [Criar um exercício](../how-to/criar-exercicio.md).
