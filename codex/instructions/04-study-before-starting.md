---
description: Fase de descoberta antes de qualquer atividade de desenvolvimento
alwaysApply: true
---

# Estudar Antes de Começar

Vale para qualquer empresa. O que muda por cliente (qual base de conhecimento, qual
tracker, quais fontes) fica na camada de contexto, em `project AGENTS.md`,
carregada pelo `AGENTS.md` do projeto.

## Fase 0: Ambiente

Verificar runtime disponível, dependências instaladas, serviços de apoio no ar.
O como é específico do projeto e está no `AGENTS.md` dele.

## Fase 1: Base de conhecimento primeiro

Se o contexto ativo declara uma base de conhecimento (RAG, wiki, pasta de docs),
consultá-la ANTES de ler arquivo, antes de grep, antes de git log, antes de fonte
externa. Esgotar o domínio antes de tentativa e erro.

Sem base declarada, começar pelo código e pelo histórico do git.

## Fase 2: Regras de negócio

Comportamento financeiro, de cobrança, de permissão ou de conformidade nunca se deduz
do código. Procurar a regra escrita. Não achou: perguntar, não inferir.

## Fase 3: Contexto e arte prévia

Ordem: base de conhecimento -> memória -> codebase -> histórico do git -> PRs
anteriores -> documentação -> chat.

Procurar quem já resolveu isso antes de resolver de novo.

## Fase 4: Aprendizados acumulados

Antes de escrever ou alterar código:

- `~/.agents/skills/codereview/references/known-gotchas.md`, nas seções que casam com o
  domínio do change
- `~/.agents/skills/codereview/references/learnings.md`, entradas do repo alvo

Consumidores formais: `/feature-dev` (references) e `/codereview` (Phase 0).
Fora de skill, aplicar manualmente. Esta regra e a fase de pesquisa: nao depende de skill.

## Compactação

Auto-compact LIGADO. O harness compacta perto do limite e os hooks `PreCompact`/
`PostCompact` anunciam antes e depois. Não pedir `/clear` nem rodar `/compact` manual em
silêncio. Skills rodam com o contexto disponível.
