---
description: Quais skills existem, quando usar, e o que a medicao de uso mostra
alwaysApply: true
---

# Skills Primeiro

Antes de dev/doc/analise: verificar se uma skill cobre. Usar.

Carregar `thinking-partner` para conversas de analise, planejamento ou decisao. Pular
para pergunta rapida, edicao de codigo e execucao de automacao.

**Encadeamento**: a cadeia flui sem interrupcao. Nao forcar `/clear` entre skills.
**Deteccao de intencao**: "cria o PR" dispara `/create-pr`. "comita" dispara `/commit`.
**Commit e PR inline**: `/commit` e `/create-pr` sao guias, nao gates. Claude pode
commitar e abrir PR direto seguindo o formato da regra 00 e o template em
`skills/create-pr/references/pr-template.md`. Carregar a skill quando o usuario pedir
ou quando precisar do checklist completo.

## Skills ativas

`/thinking-partner` | `/commit` | `/deslop` | `/create-pr` | `/codereview` |
`/feature-dev` | `/handoff` | `/investigation`

## Cadeias

| Tipo | Cadeia |
|---|---|
| Feature | `/feature-dev` -> `/deslop` -> `/commit` -> `/create-pr` |
| Bug | `/investigation` -> corrigir -> `/deslop` -> `/commit` -> `/create-pr` |
| Config, migration | alterar -> `/deslop` -> `/commit` -> `/create-pr` |

**Nunca pular `/deslop` antes do commit.** E o unico gate real da cadeia.

Antes de commit/PR mostrar progresso: `[x]` feito `[ ]` pendente `[~]` pulado.
`/deslop` em `[ ]` no commit = PARAR e executar primeiro.


Os workflows antigos permanecem no repositório para compatibilidade. O pacote portátil instala apenas as 8 skills ativas acima.
