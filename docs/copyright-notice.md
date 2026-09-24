# Nota de direitos autorais (contexto completo)

Este documento expande o aviso curto de [`NOTICE.md`](../NOTICE.md) com o
contexto completo de por que este repositório existe da forma como existe.

## Origem do projeto

O autor original deste repositório estudou para o exame RHCSA (EX200) no
próprio homelab, com apoio do material oficial **"RH199 Rapid Track Student
Workbook"**, da Red Hat Training — um material licenciado pessoalmente a
ele como parte de um curso/certificação.

Ao longo desse estudo, o autor construiu um ambiente de laboratório prático
(VMs, exercícios, scripts de correção, dashboard de progresso) para praticar
os domínios do exame de forma repetível. Este repositório é a
**reconstrução genérica e portátil** desse ambiente — a infraestrutura como
código, não o conteúdo do curso.

## O que foi deliberadamente excluído

Por respeito à licença do material original e para permitir que este
repositório seja publicado como código aberto, **nenhum conteúdo do RH199**
foi incluído:

- Nenhum enunciado de exercício do workbook foi copiado ou traduzido.
- Nenhuma solução, script ou comando específico do workbook foi transcrito.
- Nenhuma captura de tela, diagrama ou texto explicativo do material foi
  reproduzido.

## O que foi escrito do zero

Os exercícios em `labs/` foram escritos do zero pelo autor, especificamente
para este repositório, com o objetivo de cobrir os mesmos **domínios de
conhecimento publicados no blueprint oficial do exame EX200**
(<https://www.redhat.com/en/services/certification/rhcsa>) — que é, por
definição, informação pública divulgada pela própria Red Hat para qualquer
candidato se preparar.

Isso significa que:

- Os **temas** dos exercícios (gerenciamento de usuários/grupos, storage e
  LVM, NFS/autofs, SELinux, firewalld, systemd, containers, etc.) coincidem
  com o blueprint público — isso é esperado e inevitável, não é overlap com
  o workbook licenciado.
- Os **cenários, nomes, instruções passo a passo e critérios de avaliação
  (`grade.sh`)** de cada exercício são redação original do autor, escrita
  especificamente para este projeto.

Ver o [guia de autoria de exercícios](exercises-authoring-guide.md) para a
regra explícita que qualquer novo exercício precisa seguir: nunca incluir
texto do RH199, nem enunciado nem solução literal.

## Marcas registradas

"RHCSA", "RHEL", "Red Hat Enterprise Linux", "Red Hat" e "Red Hat Certified
System Administrator" são marcas registradas da Red Hat, Inc. nos Estados
Unidos e em outros países. Este projeto é um material de estudo
independente, não afiliado, patrocinado, endossado ou certificado pela Red
Hat.

## A ISO nunca é redistribuída

Este repositório nunca inclui, empacota ou redistribui a ISO do RHEL. O
usuário final precisa baixar sua própria ISO a partir de uma conta Red Hat
Developer Subscription for Individuals (gratuita) e apontar o caminho local
dela via `.env` (`RHEL_ISO_PATH`) — ver
[docs/tutorial-fim-a-fim.md](tutorial-fim-a-fim.md).

## Dúvidas ou solicitações de remoção

Se, ainda assim, algum trecho deste repositório parecer reproduzir material
licenciado da Red Hat Training, abra uma issue no repositório descrevendo o
trecho específico para revisão e remoção imediata.
