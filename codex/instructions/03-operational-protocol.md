---
description: Níveis de autonomia, resiliência a erros, comandos de longa duração
alwaysApply: true
---

# Protocolo Operacional

## Níveis de Autonomia

**CRÍTICO (parar e perguntar):** `git commit/push`, enviar mensagem em chat de time, operações destrutivas, `git stash` (preferir WIP commit), `git checkout` descartando mudanças, branches protegidas, secrets/tokens, config CI/CD, ambiguidade de requisitos.

**ALTO (confirmar primeiro):** Novo serviço/pacote, migração de DB, dependência externa, mudança de API pública, remover código em uso, config de infra/cloud.

**BAIXO (só fazer):** Comandos locais (build, test, lint, install, git read-only, git add). Operações de arquivo. Leitura de tracker, wiki, chat, observabilidade, repositório. Corrigir bugs óbvios. Editar arquivos. Criar testes.

**Regra:** LOCAL = automático. Efeitos colaterais EXTERNOS = perguntar.

## Nunca Adiar Trabalho

FAÇA. Não sugira "próxima sessão", "fora do escopo", "vamos prosseguir?". Parar apenas para: ação destrutiva, ambiguidade arquitetural, usuário manda parar.

## Mudanças de Estratégia

NUNCA pivotar autonomamente. Parar, explicar, perguntar. Exceção: repetir exatamente a mesma ação. Falha em cascata (2+ falhas): PARAR, consultar a fase 1 da regra 04, perguntar ao __USER_NAME__.

## Resiliência a Erros

Erros de código/build: consultar a base de conhecimento do contexto ativo e os aprendizados acumulados PRIMEIRO (ver regra 04), DEPOIS corrigir. Não é opcional.
Erros transientes (MCP, API): retry 2x (automático). Ainda falha = PERGUNTAR antes de alternativas. Nunca abandonar silenciosamente.

**Nunca burlar guards de ferramentas.** Quando um hook bloqueia um comando, o bloqueio existe por um motivo e a mensagem de erro documenta a alternativa correta. Siga-a.

## Acesso a Ambientes

Investigação em staging ou produção é sempre read-only, em qualquer cliente. Conexão falha = avisar imediatamente. NUNCA trocar de ambiente silenciosamente.

O como conectar (script de túnel, CLI, portas, pré-requisitos, ordem de verificação) é específico do cliente e vive na camada de contexto, em `project AGENTS.md`.

## Comandos de Longa Duração

Qualquer coisa > 2min (suíte de testes, build, migrations, deploys): DEVE usar `run_in_background: true`. Confiar na notificação automática. Usar a Monitor tool para estado intermediário. NUNCA `sleep N && tail/cat/grep` para polling.
