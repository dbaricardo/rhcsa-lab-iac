# Documentação

Organizada segundo o [Diátaxis](https://diataxis.fr): cada documento tem um
único propósito. Escolha pela sua necessidade no momento.

| Quero… | Tipo | Onde |
|---|---|---|
| aprender, montando o lab pela primeira vez | **Tutorial** | [`tutorials/`](tutorials/) |
| resolver uma tarefa específica | **Guia prático** | [`how-to/`](how-to/) |
| consultar um valor, comando ou formato exato | **Referência** | [`reference/`](reference/) |
| entender como funciona e por que é assim | **Explicação** | [`explanation/`](explanation/) |

## Tutoriais

- [Do zero ao primeiro exercício resolvido](tutorials/primeiro-lab-fim-a-fim.md)
  — pré-requisitos, ISO, `.env`, `make deploy`, dashboard e um exercício
  completo. **Comece por aqui.**

## Guias práticos

- [Operar o lab no dia a dia](how-to/operar-o-lab.md) — SSH, reaplicar o
  Ansible, mudar a topologia, reconstruir a imagem, destruir e recriar.
- [Testar sem subscription (modo offline)](how-to/deploy-offline.md)
- [Resolver problemas comuns](how-to/resolver-problemas.md) — sintoma → o
  que fazer.
- [Criar um exercício novo](how-to/criar-exercicio.md)
- [Usar Rocky Linux 10 no lugar do RHEL 10](how-to/usar-rocky-linux.md)
  (não testado)

## Referência

- [Alvos do `Makefile`](reference/makefile.md) e arquivos gerados em `output/`
- [Configuração](reference/configuracao.md) — `.env`, `machines.yaml`,
  variáveis do Terraform e do Ansible
- [Comando `lab` e dashboard](reference/comando-lab.md) — subcomandos,
  códigos de saída, endpoints
- [Contrato dos exercícios](reference/contrato-exercicios.md) — layout `labs/hosts/`, catálogo, saída do grade, guardas herdadas do homelab
- [Catálogo de exercícios](reference/catalogo-exercicios.md)
- [Testes de aceitação](reference/testes-aceitacao.md) — matriz T1–T11

## Explicação

- [Arquitetura do lab](explanation/arquitetura.md) — topologia, fluxo de
  deploy, subscription, dispatcher `lab`, por que Terraform + Ansible
- [Imagem golden](explanation/imagem-golden.md) — kickstart, sysprep e
  decisões do build
- [Problemas conhecidos e mitigações](explanation/problemas-conhecidos.md)
  — bugs reais que explicam trechos "estranhos" do código
- [Direitos autorais](explanation/direitos-autorais.md) — o que o projeto
  inclui e o que deliberadamente não inclui

## Onde cada coisa vai (para quem contribui)

- Passo a passo para quem está aprendendo → `tutorials/`
- "Como faço X?", assumindo que a pessoa já conhece o lab → `how-to/`
- Tabelas, flags, formatos, valores padrão → `reference/`
- "Por quê?", histórico de decisões, causas de bugs → `explanation/`

Se um texto mistura dois tipos, separe e ligue os dois com um link.
