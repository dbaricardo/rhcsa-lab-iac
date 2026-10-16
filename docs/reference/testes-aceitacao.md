# Referência: testes de aceitação

`tests/acceptance/run-all.sh` simula um usuário novo seguindo a
documentação num host descartável. Não para no primeiro erro: registra
PASS/FAIL e o tempo de cada fase.

```bash
bash tests/acceptance/run-all.sh             # matriz completa
bash tests/acceptance/run-all.sh --skip-t11  # sem o ciclo destroy + rebuild
```

**Atenção:** destrói e recria as VMs do lab. Rode só em host de teste.

## Matriz

| Fase | Valida |
|---|---|
| T1 | `make check-env` passa com `.env` real; falha sem `.env` e com boot ISO |
| T2 | `make build-image`: imagem gerada, sem `.partial`, sem `anaconda-ks.cfg` |
| T3 | `make infra`: 3 VMs `running`, SSH com `student_key`, discos extra da `serverb`, `terraform plan` sem mudanças |
| T4 | `make provision` sem `RHSM_*` e sem offline **falha** no assert de subscription |
| T5 | `make provision-offline` (1ª vez): `failed=0` nos 3 hosts |
| T6 | `make provision-offline` (2ª vez): idempotência |
| T7 | `tests/smoke/e2e-check.sh` |
| T8 | Dashboard web responde |
| T9 | Para cada exercício: `start` → `grade` FALHOU → solução → `grade` PASSOU → `finish` |
| T10 | Reboot das 3 VMs: dashboard, hostname FQDN e `lab grade` continuam funcionando |
| T11 | `make destroy` sem sobras + `make deploy-offline` + smoke |

## Saídas

| Arquivo | Conteúdo |
|---|---|
| `output/acceptance-<data>.log` | Log completo da execução |
| `output/acceptance-tN.out` | Saída detalhada de cada fase (para diagnóstico) |

Código de saída: `0` se tudo passou, `1` se houve falha, `2` se faltou um
pré-requisito de infraestrutura (ex.: `terraform` ausente).

## Soluções de referência

`tests/solutions/<id>.sh`: uma por exercício, idempotente, roda como root no
host do exercício. Exercícios multi-host detectam o host por `hostname -s`.

```bash
bash scripts/lab-ssh.sh servera 'sudo bash -s' < tests/solutions/users-groups-01.sh
```

## Outros testes

| Comando | Escopo |
|---|---|
| `bash tests/smoke/e2e-check.sh` | Smoke do lab já no ar |
| `make test-dashboard` | `pytest` do backend do dashboard |
| `make lint` | Terraform, Ansible e shellcheck |
