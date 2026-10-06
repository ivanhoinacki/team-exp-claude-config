# Branches e Worktrees

## Regra atual (ordem do __USER_NAME__, 2026-08-10)

NAO criar worktree. Trabalhar direto no checkout principal.

Nunca perguntar "quer criar uma worktree?". A resposta ja e nao. Worktree so volta a
existir se o __USER_NAME__ pedir nominalmente, naquela tarefa.

Qual e a branch de trabalho e qual a politica de merge muda por cliente e vive na
camada de contexto, em `project AGENTS.md`, ou no `AGENTS.md` do repo.
Nao assumir `development`, nao assumir `main`: ler o contexto ativo.

Sem contexto declarado: perguntar antes do primeiro push, nunca deduzir.

## Antes de editar: declarar onde esta

Antes da PRIMEIRA edicao de qualquer sessao que toque um repo git, declarar em uma linha:

```
repo: <path>  branch: <branch>
```

Confirmado por `pwd` e `git branch --show-current`, nunca deduzido de mensagem anterior
nem de path que o usuario citou de memoria.

Path citado pelo usuario divergindo do cwd = parar e perguntar qual vale.

Isso vale em qualquer empresa. E a defesa contra editar o repo certo na branch errada,
ou o repo errado achando que e o certo, que fica mais provavel quando se trabalha em
mais de um cliente no mesmo dia.

## Deteccao de ticket

Se o contexto ativo declara um formato de ID de ticket, toda mensagem que contenha um:
ANTES de codigo, buscar a branch correspondente nos repos daquele cliente via
`git branch -a | grep -i <ticket>`.

Encontrou: informar. Multiplos resultados: perguntar. Sem ticket: silencioso.

O formato do ID e a raiz de busca sao do cliente, nao desta regra.
