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
| T9 | Para cada um dos 25 avulsos: `start` → `grade` FALHOU → solução (`tests/solutions/legacy.sh`) → `grade` PASSOU → `finish` → `start` de novo |
| T10 | Reboot das 3 VMs: dashboard, hostname FQDN e `lab grade` continuam funcionando |
| T11 | `make destroy` sem sobras + `make deploy-offline` + smoke |
| T12 | `examsim-full`: `start` prepara 24 questões, `grade` recusado, `finish` dá `Nota X/24` e limpa |
| T13 | `examsim-dinamico` com as seeds `DYN_SEEDS` (padrão `3694 1091 47 1478 11 48 50`, que juntas cobrem as 24 legadas): soluções `qa/solve-exam.sh` + `qa/solve-legacy.sh` → `Nota 24/24` em todas; nenhuma prova fica aberta |

## Saídas

| Arquivo | Conteúdo |
|---|---|
| `output/acceptance-<data>.log` | Log completo da execução |
| `output/acceptance-tN.out` | Saída detalhada de cada fase (para diagnóstico) |

Código de saída: `0` se tudo passou, `1` se houve falha, `2` se faltou um
pré-requisito de infraestrutura (ex.: `terraform` ausente).

## Soluções de referência

`tests/solutions/legacy.sh`: as 25 soluções avulsas num só script (`--list`,
`--host <id>`), roda como root no host da questão. Ver
`tests/solutions/README.md`.

```bash
host=$(bash tests/solutions/legacy.sh --host examsim-cron)
bash scripts/lab-ssh.sh "$host" 'sudo bash -s -- examsim-cron' < tests/solutions/legacy.sh
```

Exame dinâmico: `/usr/local/lib/lab-dyn/qa/solve-exam.sh` e `solve-legacy.sh`
(na workstation), mais `qa/validate-ported.sh` para validar as 142 tarefas
portadas uma a uma.

## Outros testes

| Comando | Escopo |
|---|---|
| `bash tests/smoke/e2e-check.sh` | Smoke do lab já no ar |
| `make test-dashboard` | `pytest` do backend, wrapper, catálogo e revisão por IA |
| `python3 -m pytest labs/dyn/tests` | Motor e pool do exame dinâmico |
| `make lint` | Terraform, Ansible e shellcheck |
