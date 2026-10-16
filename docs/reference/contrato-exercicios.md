# Referência: contrato dos exercícios

Especificação do que um exercício em `labs/` precisa cumprir. Para o passo
a passo de criar um, ver [Criar um exercício](../how-to/criar-exercicio.md).

## Estrutura

```
labs/<id>/
├── meta.json   # metadados (dashboard e dispatcher `lab`)
├── start.sh    # prepara o ambiente
├── grade.sh    # avalia, sem alterar nada
└── finish.sh   # limpa
```

`labs/catalog.json` é gerado (`make catalog`) e é o que a `workstation`
usa. Os scripts são instalados em `/usr/local/lib/lab-scripts/<id>/` nos
hosts listados em `hosts`.

## `meta.json`

Schema: `labs/catalog.schema.json` (JSON Schema draft-07).

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `id` | string | sim | `^[a-z0-9-]+$`, igual ao nome do diretório |
| `number` | inteiro ≥ 1 | sim | Único; define a ordem no catálogo |
| `title` | string | sim | Título curto |
| `domain` | string | sim | Domínio do blueprint EX200 |
| `hosts` | lista | sim | 1+ de `workstation`, `servera`, `serverb`, na ordem de `start`/`grade` |
| `description` | string | sim | Resumo do cenário |
| `instructions` | lista de strings | sim | Enunciado, item a item |
| `warning` | string | não | Aviso exibido no dashboard |
| `solve_target` | string | não | Onde resolver (ex.: `servera`) |
| `solve_method` | string | não | `ssh` ou `console` |
| `solve_command` | string | não | Comando para chegar ao host |
| `solve_note` | string | não | Observação extra |

## Saída de `grade.sh`

O dashboard faz parsing deste formato. Fora dele, o painel mostra "erro de
infraestrutura".

| Linha | Formato |
|---|---|
| Critério aprovado | `OK: <descrição>` |
| Critério reprovado | `FALHOU: <descrição>` |
| Resultado (uma vez, no fim) | `RESULTADO: PASSOU` ou `RESULTADO: FALHOU` |

```
OK: usuário ana existe
FALHOU: grupo equipe-suporte não contém ana
RESULTADO: FALHOU
```

- Código de saída `0` tanto para PASSOU quanto para FALHOU. Diferente de
  `0` só se o próprio grader quebrou.
- Multi-host: cada host emite seus próprios `OK:`/`FALHOU:` e sua linha
  `RESULTADO:`. O banner `==> lab grade <id> (<host>)` é impresso pelo
  `lab`, não pelo script.

## `start.sh` e `finish.sh`

| Script | Contrato |
|---|---|
| `start.sh` | Idempotente: rodar duas vezes seguidas não quebra nada. Sai `0` em sucesso |
| `finish.sh` | Inverso **explícito** do `start.sh` e de tudo que o estudante possa ter criado. Nunca chama `start.sh`. Reverte config compartilhada (portas, `httpd.conf`…). Sai `0` em sucesso |

Ordem em exercícios multi-host: `start`/`grade` seguem `hosts`; `finish`
segue a ordem inversa (cliente desmonta antes de o servidor remover o
export).

## Helpers de disco (`/usr/local/lib/lab-common.sh`)

Uso: `source /usr/local/lib/lab-common.sh`.

| Função | Retorna |
|---|---|
| `disco_do_so` | Disco que contém a raiz do sistema |
| `resolve_disco <tamanho_gb> [tolerancia_gb=1]` | Disco **cru** (sem partições) com o tamanho pedido, excluindo o disco do SO. Para `start.sh` |
| `disco_por_tamanho <tamanho_gb> [tolerancia_gb]` | Disco com o tamanho pedido, com ou sem partições. Para `finish.sh` |

Nunca use nomes fixos (`/dev/sdb`, `/dev/vdb`).

## Proibições

- Texto do RH199 (enunciado ou solução), em qualquer forma — ver
  [Direitos autorais](../explanation/direitos-autorais.md).
- Imprimir senhas ou segredos reais na saída dos scripts.

## Soluções de referência

`tests/solutions/<id>.sh`: solução idempotente, rodada como root em cada
host do exercício, usada só pelo teste de aceitação (T9). Ver
[Testes de aceitação](testes-aceitacao.md).
