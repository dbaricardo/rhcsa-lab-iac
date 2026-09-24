# Arquitetura

## Topologia

Três VMs libvirt, todas clonadas do mesmo box golden `rhel10-rhcsa-base`,
ligadas por uma rede privada libvirt (`machines.yaml` -> `network`), com IP
estático por VM (nunca DHCP na topologia final):

```
                         rede privada libvirt "rhcsa_lab"
                         192.168.56.0/24 (gateway 192.168.56.1)
      host (seu PC) ────────────────┬──────────────────────────┐
                                     │                          │
                          192.168.56.10                 192.168.56.20 / .30
                    ┌────────────────────────┐      ┌─────────────────────────┐
                    │      workstation        │      │   servera / serverb     │
                    │  (role: client)          │      │   (role: server)        │
                    │                          │      │                         │
                    │  systemd:                │ SSH  │  /usr/local/bin/        │
                    │   rhcsa-lab-dashboard ───┼──────┼─ lab-remote             │
                    │   (porta 8421, HTTP)     │◄─────┼─ (dispatcher local)     │
                    │                          │      │                         │
                    │  /usr/local/bin/lab      │      │  /usr/local/lib/        │
                    │  (dispatcher remoto)     │      │   lab-scripts/<id>/     │
                    │                          │      │   (start/grade/finish)  │
                    └────────────────────────┘      └─────────────────────────┘
                                                        serverb tem, além disso,
                                                        2 discos extra brutos
                                                        (6GB + 1GB) para
                                                        exercícios de storage/LVM
```

- `workstation` (192.168.56.10, 2 vCPU / 2GB): onde o estudante trabalha.
  Roda o dashboard web e o dispatcher `lab`.
- `servera` (192.168.56.20, 2 vCPU / 2GB): host "servidor" alvo da maioria
  dos exercícios single-host.
- `serverb` (192.168.56.30, 2 vCPU / 2GB, + discos extra de 6GB e 1GB): host
  "servidor" com armazenamento extra bruto, para exercícios de
  partição/LVM/filesystem que precisam de um disco do zero.

Toda a especificação (nomes, IPs, memória, CPUs, discos extra) vem de um
único arquivo, `machines.yaml` — é a fonte de verdade lida tanto pelo
`Vagrantfile` (Ruby, via `YAML.load_file`) quanto pelos roles Ansible (via
`lookup('file', ...) | from_yaml`) quanto por `scripts/build-box.sh`. Isso
evita que a topologia fique duplicada e divergente entre Vagrant e Ansible.

## Dashboard não é uma 4ª VM

O dashboard web (`ansible/roles/dashboard/`) é um **serviço systemd
(`rhcsa-lab-dashboard.service`) rodando dentro da própria `workstation`**,
servindo um backend HTTP simples em Python (`http.server`, sem framework)
na porta 8421, com um índice HTML estático e uma API somente leitura
(`GET /api/state`, `GET /healthz`).

Por quê:

- O dashboard só existe para visualizar o progresso que o dispatcher `lab`
  já registra localmente (SQLite em `/var/lib/rhcsa-lab-dashboard`) — não há
  necessidade de rede, isolamento ou ciclo de vida independentes que
  justifiquem uma VM própria.
- Uma VM a mais custaria RAM/CPU do host sem nenhum ganho arquitetural: o
  dashboard não processa nada que o dispatcher já não tenha processado.
- Manter os dois no mesmo host simplifica o acesso ao mesmo banco SQLite
  (`ProgressStore`, compartilhado entre `backend.py` e o dispatcher `lab`)
  sem precisar de rede entre eles.

O acesso HTTP externo (do seu navegador, fora da rede do lab) é controlado
por uma regra `firewalld` explícita, restrita à origem configurada em
`machines.yaml` -> `dashboard.allowed_source` (por padrão, apenas a própria
rede privada do lab).

## Dispatcher remoto (`lab`) x dispatcher local (`lab-remote`)

O modelo é deliberadamente assimétrico:

- **`lab`** (Python, instalado só na `workstation` pelo role `workstation`,
  arquivo `ansible/roles/workstation/files/lab`) é o único comando que o
  estudante digita. Ele:
  1. lê `catalog.json` (gerado por `scripts/build-catalog.py` a partir dos
     `meta.json` de cada exercício em `labs/`) para saber quais hosts um
     exercício usa e em que ordem;
  2. para cada host declarado no exercício, invoca
     `sudo /usr/local/bin/lab-remote <ação> <id>` — via SSH (chave ed25519
     distribuída pelo role `ssh_crosshost`) quando o alvo é `servera`/
     `serverb`, ou diretamente (sem SSH) quando o alvo declarado é a própria
     `workstation` (caso de exercícios como `shell-scripting-01`, para os
     quais o role `lab_common` também é aplicado à workstation);
  3. **nunca executa a lógica de um exercício num host diferente do que o
     `meta.json` declara** — se o host correto for outro e estiver
     inacessível, falha explicitamente com código de saída 2, em vez de
     silenciosamente pular a etapa ou rodar em substituição no host errado;
  4. registra o resultado (saída, código de retorno, timestamps) no mesmo
     banco SQLite que o dashboard lê, via a classe `ProgressStore`
     (compartilhada com `backend.py`).
- **`lab-remote`** (Bash, instalado em `servera`/`serverb`/`workstation`
  pelo role `lab_common`) só sabe rodar
  `/usr/local/lib/lab-scripts/<id>/<ação>.sh` no host local. Não tem
  conhecimento de topologia, catálogo ou dashboard — não deve (e não é
  esperado) ser chamado diretamente pelo estudante.

Essa separação existe para que a lógica de "que host(s) este exercício usa"
viva em **um único lugar** (o catálogo, consumido pelo `lab` remoto), em vez
de espalhada em cada script de exercício.

## Ordem de execução do Ansible

`site.yml` roda em 4 plays, na ordem:

1. `common` + `ssh_crosshost` contra `hosts: all` — precisam rodar juntos,
   na mesma play, porque `ssh_crosshost` usa `hostvars` para levar a chave
   pública gerada na `workstation` até `servera`/`serverb` na mesma
   execução (evita condição de corrida entre gerar a chave numa execução do
   playbook e distribuí-la só na próxima).
2. `servera` + `lab_common` contra `hosts: servera`.
3. `serverb` + `lab_common` contra `hosts: serverb`.
4. `dashboard` + `workstation` contra `hosts: workstation` — o role
   `dashboard` roda antes de `workstation` para que `/opt/rhcsa-lab-dashboard`
   (com `backend.py`, importado por `lab` via `sys.path.insert`) já exista
   quando o dispatcher `lab` for instalado.

O `Vagrantfile` dispara esse playbook uma única vez, como provisioner da
**última** VM criada (`workstation`, por ordenação determinística em
`ORDERED_NAMES`), com `ansible.limit = 'all'` — ou seja, o Ansible só roda
depois que as 3 VMs já existem, evitando condição de corrida no role
`ssh_crosshost` (que precisa de `servera`/`serverb` de pé para autorizar a
chave da `workstation` neles).

## Sem Packer

O box golden é construído direto por `virt-install` + kickstart
(`scripts/build-box.sh`), sem passar por Packer. Decisão deliberada: reduzir
o número de ferramentas que o usuário final precisa instalar e aprender.
`virt-install` já é necessário de qualquer forma (é o mecanismo usado para a
instalação desassistida), então evitar Packer elimina uma dependência
inteira sem perder determinismo — o fluxo inteiro (kickstart -> instalação
-> sysprep offline via `virt-customize` -> empacotamento como box
`vagrant-libvirt`) é reproduzível e não depende de nenhum builder externo.

## RHEL 10 real, não uma distribuição derivada

O objetivo do laboratório é treinar para um exame aplicado sobre RHEL de
verdade, incluindo comportamentos que só existem por causa do registro via
subscription (repositórios, bug de GPG da 4ª chave — ver
[troubleshooting.md](troubleshooting.md)). Por isso o projeto usa a ISO RHEL
10 real do usuário, registrada via Red Hat Developer Subscription for
Individuals (gratuita), em vez de uma distribuição binariamente compatível.
Há uma [nota de fallback com Rocky Linux](rocky-linux-fallback.md) para quem
quiser testar só a mecânica da infraestrutura, mas esse caminho não é
mantido com o mesmo rigor.
