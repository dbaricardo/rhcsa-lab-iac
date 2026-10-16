# Referência: configuração

Três arquivos controlam o lab: `.env` (segredos e caminhos locais),
`machines.yaml` (topologia) e as variáveis do módulo `terraform/`.

## `.env`

Copiado de `.env.example`. Nunca é commitado (`.gitignore`).

| Variável | Obrigatória | Padrão | Uso |
|---|---|---|---|
| `RHEL_ISO_PATH` | sim | — | Caminho absoluto da **DVD ISO** x86_64 do RHEL 10 (não a boot ISO). Lida por `build-image.sh`, `check-env.sh` e `offline-repo.sh` |
| `STUDENT_PASSWORD` | sim | — | Senha do usuário `student`. Entra no kickstart só como hash SHA-512 |
| `RHSM_ORG_ID` | não | vazio | Organization ID da conta Red Hat. Com `RHSM_ACTIVATION_KEY`, faz o Ansible registrar cada VM |
| `RHSM_ACTIVATION_KEY` | não | vazio | Activation key da conta Red Hat |
| `APPLY_SECURITY_UPDATES` | não | `false` | `true` roda `dnf -y update --security` no fim do kickstart |

Sem `RHSM_*`, `make provision` só passa se as VMs já estiverem registradas
à mão; `make deploy-offline` ignora essas variáveis.

## `machines.yaml`

Fonte única da topologia, lida pelo Terraform (`yamldecode`), pelos roles
Ansible e por `scripts/build-image.sh`.

| Chave | Padrão | Significado |
|---|---|---|
| `domain` | `lab.example.com` | Domínio DNS das VMs (`servera.lab.example.com`) |
| `image` | `rhel10-rhcsa-base` | Nome da imagem golden (`output/<image>.qcow2`) |
| `network.libvirt_name` | `rhcsa_lab` | Nome da rede libvirt |
| `network.cidr` | `192.168.56.0/24` | Rede NAT do lab |
| `network.gateway` | `192.168.56.1` | IP do host na rede; serve o repo offline na porta 8080 |
| `student.username` | `student` | Usuário criado pelo kickstart |
| `dashboard.host` | `workstation` | VM que roda o dashboard |
| `dashboard.port` | `8421` | Porta HTTP do dashboard |
| `dashboard.allowed_source` | `192.168.56.0/24` | Origem liberada no `firewalld` para o dashboard |
| `machines.<nome>.ip` | ver abaixo | IP fixo (reserva DHCP na rede libvirt) |
| `machines.<nome>.memory_mb` | `2048` | RAM da VM |
| `machines.<nome>.cpus` | `2` | vCPUs |
| `machines.<nome>.role` | `client`/`server` | Papel da VM |
| `machines.<nome>.extra_disks[]` | só `serverb` | Discos brutos extra: `label` + `size_gb` |

VMs padrão:

| VM | IP | Discos extra |
|---|---|---|
| `workstation` | `192.168.56.10` | — |
| `servera` | `192.168.56.20` | — |
| `serverb` | `192.168.56.30` | `vmdata1` 6 GB, `vmdata2` 1 GB |

## Variáveis do Terraform (`terraform/variables.tf`)

| Variável | Padrão | Significado |
|---|---|---|
| `libvirt_uri` | `qemu:///system` | Conexão libvirt |
| `storage_pool` | `default` | Pool onde ficam os volumes (precisa existir) |
| `name_prefix` | `rhcsa-lab` | Prefixo de domínios e volumes (`rhcsa-lab-servera`, `rhcsa-lab-base.qcow2`…) |

Para sobrescrever: `terraform -chdir=terraform apply -var storage_pool=outro`.

Versões fixadas em `terraform/versions.tf`: Terraform `>= 1.5`, provider
`dmacvicar/libvirt` **`0.8.3`**, `hashicorp/local` `~> 2.5`.

Outputs: `vms` (domínio e IP por VM), `dashboard_url`, `inventory`.

## Variáveis do Ansible

Definidas em `ansible/group_vars/all.yml` e no inventário gerado pelo
Terraform:

| Variável | Origem | Uso |
|---|---|---|
| `lab_domain`, `lab_student_user`, `lab_network_cidr` | `group_vars` / inventário | Hostname FQDN, usuário, rede |
| `dashboard_host`, `dashboard_port`, `dashboard_allowed_source`, `dashboard_bind_host` | `group_vars` / inventário | Serviço do dashboard |
| `lab_rhsm_org_id`, `lab_rhsm_activation_key` | env `RHSM_*` | Registro da subscription (role `common`) |
| `lab_offline_repo_url` | `-e` em `provision-offline` | Vazio = modo normal; preenchido = repos da ISO, sem subscription |

## Placeholders do kickstart (`kickstart/ks.cfg.tpl`)

Renderizado por `envsubst`, restrito a estas três variáveis:

| Placeholder | Origem |
|---|---|
| `${STUDENT_USER}` | `machines.yaml` → `student.username` |
| `${STUDENT_PASSWORD_HASH}` | `openssl passwd -6` de `STUDENT_PASSWORD` |
| `${STUDENT_SSH_PUBKEY}` | `output/student_key.pub` |
