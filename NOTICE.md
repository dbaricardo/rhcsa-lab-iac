# NOTICE

Este repositório reconstrói, de forma genérica e portátil, um ambiente de
estudos para o exame **RHCSA (EX200)** da Red Hat que o autor original
montou no próprio homelab.

## O que NÃO está aqui

O ambiente de referência original foi montado com apoio do material oficial
**"RH199 Rapid Track Student Workbook"**, da Red Hat Training, licenciado
pessoalmente ao autor.

**Nenhum conteúdo desse workbook — enunciados, soluções, textos, capturas de
tela ou qualquer material licenciado da Red Hat Training — está incluído,
copiado ou parafraseado neste repositório.**

## O que está aqui e de onde veio

Os exercícios são os mesmos do lab RHCSA que o autor usa no homelab, em
três origens:

| Conteúdo | Origem | Licença |
|---|---|---|
| 24 questões `examsim-*` e a prova completa `examsim-full` (`labs/hosts/`, `ansible/roles/workstation/files/lab-full/`) | Enunciados adaptados do simulado público em vídeo "RHCSA v10" (YouTube, `kBsMuA-DA9E`, itens 2–20 e 22) mais 4 questões do autor (Q01, Q21, Q23, Q24); scripts de preparo, correção e limpeza escritos do zero | deste repositório |
| `examsim-treino-storage` | escrito do zero pelo autor | deste repositório |
| 142 tarefas portadas do exame dinâmico (`labs/dyn/tasks/`, enunciados em `labs/dyn/pool.json`) | Portadas para bash a partir do [rhcsa-simulator](https://github.com/TroggoMan/rhcsa-simulator), de Austin Nicely; correção reescrita (comportamento, não texto) | MIT — ver [`labs/dyn/LICENSE-rhcsa-simulator`](labs/dyn/LICENSE-rhcsa-simulator) |

Todos cobrem os domínios **públicos** do blueprint oficial do EX200
(<https://www.redhat.com/en/services/certification/rhcsa>). O motor de
sorteio, o dashboard, o dispatcher `lab` e a infraestrutura são do autor.

Para mais contexto, ver
[docs/explanation/direitos-autorais.md](docs/explanation/direitos-autorais.md).

## Uso da marca

"RHCSA", "RHEL", "Red Hat" e "Red Hat Certified System Administrator" são
marcas registradas da Red Hat, Inc. Este projeto não é afiliado, endossado
ou certificado pela Red Hat — é um ambiente de estudo independente,
construído por um estudante para uso pessoal e agora compartilhado como
código aberto.

## Dúvidas ou solicitações

Se você identificar qualquer trecho que pareça reproduzir material
licenciado, abra uma issue no repositório para revisão e remoção.
