# Tarefas do rhcsa-simulator que NÃO entram no pool

O pool só aceita tarefas das categorias do EX200 **v10** (`config/exam_objectives.py`,
`OBJECTIVES_V10`). Dentro dessas categorias o simulador marca algumas tarefas com
`exam_versions`; quem é só da v9 fica de fora.

| Tarefa do simulador | Domínio | Motivo |
|---|---|---|
| `part_mbr_create` | D4 | `exam_versions = (9,)`: a v10 restringiu "listar, criar e apagar partições" a discos **GPT**; MBR está fora do programa. |

## Adaptações em tarefas portadas (não são exclusões)

- **gdisk e growpart** não estão instalados nas VMs (o mirror `content.example.com:8091` tem só 53 RPMs).
  `part_gpt_create` e `part_resize` aceitam `parted` ou `fdisk`/`resize2fs`; os enunciados citam só essas ferramentas.
- **`fs_unmount`** não usa disco: o cenário é um `tmpfs` com um processo segurando o diretório.
- **LVM de cenário** (`lvm_lv_create`, `lvm_extend`, `lvm_lv_remove`, `lvm_lv_reduce`, `fs_extend`) cria o VG/LV
  no disco de prática do host em vez de loop device.
- **NFS e autofs**: a workstation exporta `/exports/dyn-*` (um por tarefa) e o `grade` testa o comportamento
  (acessar o caminho e conferir o mount NFS), não só os arquivos de configuração.

## Fase 3 (domínios 3 e 8): adaptações

- **Scripting com correção comportamental.** Os graders do simulador só procuram texto (`$1`, `if/fi`, `for`, `$(`), o que aprovaria um script que não faz nada. Aqui o `grade` **executa** o script com entradas de teste e confere a saída e o código de saída; por isso os enunciados dizem exatamente o comportamento esperado (o do simulador é vago: "imprime uma saudação").
- **Shells:** `/bin/zsh` e `/bin/tcsh` ficam fora da troca de shell (não estão instalados; `/etc/shells` só tem `sh` e `bash`).
- **Usuários de teste:** `apache`, `nginx`, `webadmin`, `developer`, `operator` e `admin` do simulador não existem (ou colidem com contas do sistema, como `operator`). As ACLs usam `nobody/daemon/bin` ou contas criadas na tarefa (`aclweb`…); o dono recursivo usa `root/nobody`.
- **Grupos:** os nomes foram trocados para não colidir entre tarefas nem com o `sysadmin` do lab legado (`developers`/`team`/`shared` → `projdev/projteam/projshared`; `webteam` do recursivo → `webdata/devdata`).
- **`sched_cron_dir`:** os scripts não levam ponto no nome (`log-cleanup`, não `log-cleanup.sh`) e o grade usa `run-parts --test`: o `run-parts` ignora nomes com ponto, uma armadilha real de prova.
- **`sched_at`:** só especificações relativas (`now + N`), porque o grade confere o horário agendado; `tomorrow` e horários fixos ficaram de fora.
- **`perm_umask`:** a correção abre um login (`su -`) do usuário e confere o `umask` e o modo de um diretório criado com `mkdir` (o `mktemp -d` ignora o umask). O padrão de um usuário comum neste RHEL 10 é `0022`, então nenhum par nasce já resolvido (o `start` recusa se nascer).
- **`passwd_aging`/`troubleshoot_user`:** conferem os campos do `/etc/shadow` (máximo, mínimo, aviso, inatividade, expiração) em vez de só ler o texto do `chage -l`.
- **Fora do pool:** nenhuma (as 33 tarefas de D3 e D8 da v10 foram portadas).

## Fase 4 (domínios 6 e 7): adaptações

- **Serviços são unidades de laboratório, não serviços reais.** As tarefas de `services` usam `labXXXNN.service` (executando `sleep infinity`) em `/usr/lib/systemd/system`, nunca `sshd`, `chronyd`, `firewalld` etc. Motivo: parar, mascarar ou "quebrar" um serviço real do host pode tirar a VM do ar (já aconteceu com um `fuser -km` na Fase 2). As unidades moram em `/usr/lib/systemd/system`, como as do fornecedor, porque `systemctl mask` não consegue mascarar um arquivo real em `/etc/systemd/system`; um `systemctl edit` cria o drop-in em `/etc`, igual a um serviço de verdade. Os timers ficam em `/etc/systemd/system`, como o enunciado manda.
- **Sem serviços reais de SELinux.** `samba`, `nginx` e `vsftpd` não estão instalados (o mirror tem só 53 RPMs). Os enunciados descrevem o sintoma e o domínio (`httpd_t`, `smbd_t`, `ftpd_t`) e a correção confere **contexto, booleano e porta**; não há checagem de "serviço sobe". Isso cobre o que a prova cobra.
- **Sem AVC injetado.** O simulador grava um registro AVC sintético no `audit.log`. Aqui o `ausearch` não enxerga um registro isolado, e mexer no `audit.log` ao vivo arrisca o auditd, então o aluno diagnostica por `ls -Z`, `matchpathcon` e `semanage fcontext -l`. (Ficou uma linha de teste inofensiva no `audit.log` da servera: `pid=1234 comm="httpd"`.)
- **Correção de contexto olha a política.** Para os cenários de `fcontext`, além do tipo atual, o grade exige que `matchpathcon` devolva o tipo certo: ou seja, a correção sobrevive a um relabel (vale para `restorecon` simples em `/var/www/…` e para `semanage fcontext` fora dele).
- **`selinux_mode`** altera o modo de verdade (runtime e `/etc/selinux/config`) e **conflita** com as tarefas legadas que exigem Enforcing (`examsim-rootpw-recover-node2` na serverb e `examsim-selinux-httpd` na servera): nunca saem na mesma prova no mesmo host.
- **Firewall:** o `troubleshoot` não usa `ssh` (removê-lo da zona pública bloquearia o acesso às VMs). Todas as tarefas de firewall conflitam entre si por host (uma por host) e restauram **toda** a configuração (`/etc/firewalld` + estado do serviço), com `restorecon`: o `tar` não preserva o rótulo e, sem ele, o firewalld confinado não consegue gravar.
- **Timers:** o OnCalendar é comparado pela **forma normalizada** (`systemd-analyze calendar`), então `daily` e `*-*-* 00:00:00` valem o mesmo; as durações pelo valor em µs (`5min` = `300s`). Na conversão de cron, o enunciado **não** dá o OnCalendar (o simulador dá), só o cron e a descrição.
- **`svc_manage_proc`** pede para gravar o PID do processo principal num arquivo (o simulador só conferia que o processo existia), o que torna o resultado verificável.
- **`svc_restart_policy`** inclui um teste real: o grade mata o processo principal e confere que o systemd o reinicia em ~`RestartSec` segundos (a correção dessa tarefa leva até ~35 s).
- **Fora do pool:** nenhuma das 32 tarefas restantes de D6/D7.

## Fase 5 (domínios 1 e 5): adaptações e exclusões

- **Sem internet: o mirror da sala (`content.example.com:8091`) faz o papel de Rocky/Alma/EPEL.** O simulador usa repositórios públicos; aqui os enunciados apontam para o BaseOS/AppStream do mirror (`/rhel10.0/x86_64/dvd/`) e para o `/timer-repo` (pacote `logger`, não assinado: `gpgcheck=0`). A servera não tem nenhum repositório configurado, então as tarefas de instalar/remover pacote criam `dyn-lab-mirror.repo` no `start` e o removem no `finish`.
- **Pacotes só da lista que o mirror e o dnf aguentam.** Instalar/remover usa `tree`, `nano`, `wget`, `bind-utils`, `tcpdump` (o `start` leva o pacote ao estado oposto e o `finish` devolve o estado original). `unzip` ficou fora (arrasta `zip`/`rpm-build`) e `rsync` também (o mirror tem versão mais nova que a instalada, então reinstalar mudaria o host). Versões podem diferir da original após reinstalar do mirror; o QA compara só a presença.
- **`pkg_verify` altera de verdade** um arquivo de configuração (`/etc/wgetrc` ou `/etc/nanorc`) para o `rpm -V` ter o que acusar; o `finish` restaura com `restorecon`. O grade exige a linha do `rpm -V` daquele arquivo no resultado.
- **`pkg_history` e `pkg_provides`** conferem o conteúdo contra o estado real (IDs que existem no histórico; pacote dono do arquivo via `rpm -qf`). O enunciado pede "pelo menos as 10 últimas transações" porque o `dnf history list` imprime um cabeçalho do subscription-manager que come linhas de um `head` curto.
- **Fora do pool:** `pkg_downgrade` (o mirror tem uma só versão de cada pacote), `pkg_group` (o mirror não tem dados de grupos), `repo_gpg` (o mirror não tem chave GPG) e `flatpak_runtime` (instalar o `flatpak` exigiria um RPM que o mirror não tem; a servera já o traz). A tarefa do simulador de adicionar o Flathub foi trocada pelo remote de sistema do lab (`flatpak.lab.example.com:8091`), que é o que existe offline.
- **Flatpak só na servera** (a serverb não tem o pacote). Os aplicativos vêm do repositório do lab (`com.vscodium.codium`, `md.obsidian.Obsidian`); os runtimes vêm do Flathub (internet). `flatpak_install`/`flatpak_remove` levam cerca de 1 minuto no `start` ou no grade. O `finish` desinstala as refs novas (comparação com a lista do início) e apaga o remote criado; `flatpak_list` lista o que o remote **oferece** (`remote-ls`), porque nada vem instalado no começo.
- **Rede em interface virtual.** Todas as tarefas de `nmcli` trabalham na `dyn0` (tipo `dummy`); a `ens18` (gerência/SSH) nunca é tocada, e nenhum perfil recebe gateway padrão (os perfis levam `ipv4.never-default yes`; só rotas estáticas via `192.168.77.1`). Um teste barra `ens18` e `ipv4.gateway` nesses scripts. O `finish` apaga todo perfil/interface `dyn*` (`net_wipe`). As tarefas de DNS usam servidores sempre alcançáveis (`192.168.56.1`, `8.8.8.8`, `1.1.1.1`, `8.8.4.4`).
- **Rede que o simulador não tinha:** `net_route` (rota estática, que está no programa v10 mas não tinha tarefa) e `net_restart` com teste de comportamento (o perfil é editado e a interface continua com o endereço antigo até o aluno reiniciar a conexão). `net_dhcp` confere o perfil (não há servidor DHCP na `dyn0`); `net_verify` confere o `ping` salvo (contagem exata, respostas do alvo, 0% de perda).
- **Conflitos:** repos/instalação de pacote usam o recurso `repo@{host}` (o mesmo das legadas `examsim-repo-node1/2`); flatpak, `flatpak@servera`; rede, `nic-dyn0@{host}`.

## Fase 6 (domínio 2): adaptações e exclusões

- **Nenhuma tarefa reinicia a VM.** O simulador marca várias com `requires_reboot`; aqui o grade confere o estado que o reboot aplicaria (`grubby --info=DEFAULT`, `grub.cfg`, `fstab`, alvo do systemd) e os enunciados dizem "não reinicie". Um teste barra `reboot`/`poweroff`/`systemctl isolate` em qualquer script de tarefa.
- **Tudo que toca o carregador de boot é guardado e devolvido** (`boot_save`/`boot_restore`: `/etc/default/grub`, `grub.cfg`, `grubenv`, `/etc/kernel/cmdline`, entradas BLS, com `restorecon`). O QA compara os md5 e a contagem de rótulos SELinux antes e depois. O initramfs é copiado antes do `dracut -f` e devolvido no finish (mesmo mtime/md5).
- **Argumentos de kernel inofensivos.** `net.ifnames=0`, `ipv6.disable=1` e `systemd.unit=…` do simulador ficaram de fora: se a VM reiniciasse com um deles, a ens18 sumiria ou o boot mudaria e o SSH cairia. O pool usa `audit=1`, `nofb`, `biosdevname=0`, `loglevel=5`, `transparent_hugepage=never` (adicionar) e `nofb`, `audit=0`, `biosdevname=0`, `nosplash` (remover). No RHEL 10 as entradas BLS guardam as opções, então o grade olha o kernel padrão pelo `grubby`, não só o `/etc/default/grub`.
- **fstab:** o finish remove só as linhas do ponto de montagem da tarefa (outras tarefas, como as de NFS e swap, mexem no mesmo arquivo). A tarefa `dyn-fstab-fix` não tem o cenário NFS inalcançável do simulador (o `mount -a` ficaria minutos pendurado). **`mount -a` não é conferido**: com `nofail` e dispositivo ausente ele devolve 32 mesmo assim, o que reprovaria quem mantém a entrada; vale o `findmnt --verify` sem `[E]`.
- **Root somente leitura sem tocar o `/`.** O simulador remontava o `/` como `ro`; aqui o cenário é uma imagem ext4 de 64 MB em `/mnt/dynro` (loop gravável, sistema de arquivos montado `ro`), e o aluno faz `mount -o remount,rw` e grava o arquivo pedido.
- **Chroot:** o grade confere diretório, subdiretórios e os bind mounts ativos (tipo `proc`, `sysfs`, `devtmpfs`, `devpts`, `tmpfs`); o `chroot … /bin/bash` do simulador não funcionaria num diretório vazio. O finish só desmonta (do mais fundo ao mais raso) e usa `rmdir`, nunca `rm -r` (o diretório tem `/dev` montado).
- **Journal:** só o boot atual (`-b 0`) e só `err`/`warning`: as VMs têm um boot no journal e nenhuma mensagem `crit`. As unidades do filtro são as que sempre têm entradas (`sshd`, `crond`, `chronyd`, `firewalld`, `NetworkManager`, `systemd-logind`). O grade confere as 5 primeiras linhas do resultado real, não só a existência do arquivo.
- **Fora do pool:** `boot_recovery_root_pw_reset` e `boot_recovery_root_pw_sulogin` (exigem reiniciar com `rd.break` no console; a legada `examsim-rootpw-recover-node2` já cobre isso) e `boot_selinux_relabel` (igual à `dyn-selinux-relabel` do domínio 7).
- **`examsim-ntp` passou a categoria `services`.** Como só ela tinha a categoria `time_services` e o sorteio espalha as vagas por categoria, ela entrava em 100% das provas; agora disputa a vaga com as outras tarefas de serviços e **nenhuma questão é mais fixa** (0 em 2000 sorteios).
- **Conflitos:** `grub@{host}` (GRUB/argumentos), `default-target@{host}` (também usado por `dyn-boot-default-target`), `fstab@{host}`, `initramfs@{host}`, `chroot@{host}`, `dynro@{host}` e `journald@{host}` (as tarefas de journal leem o log, então não podem coexistir com as que reiniciam o journald).

## QA das questões legadas (2026-10-05/06)

- `qa/solutions-legacy.sh` + `qa/solve-legacy.sh` trazem a solução de referência das 24 legadas (`examsim-*`), no host de cada questão; o `solve-exam.sh` só resolve as portadas. Os discos da serverb são achados pelo tamanho (1 GiB e 6 GiB).
- **Exceção:** `examsim-rootpw-recover-node2` é resolvida por `chpasswd`, porque o procedimento real (`rd.break` no console da serverb (`virsh console rhcsa-lab-serverb`)) não é automatizável por SSH. Isso valida start/grade/finish, **não** o procedimento de recuperação.
- Ciclos E2E reais com portadas + legadas resolvidas (seeds 3694, 1091, 47, 1478, 11, 48, 50, cobrindo as 24 legadas): **24/24 em todos** e retrato das 3 VMs idêntico (contas, `group`/`shadow`/`gshadow`, crontabs, chrony, tuned, LVM, swap, autofs, httpd, flatpak, rede, rótulos SELinux).
- O QA achou 2 resíduos de 29/09 nas VMs que quebravam questões legadas (`/searchfile` como diretório na servera e `/database` como arquivo na serverb, ambos vazios); foram removidos.

