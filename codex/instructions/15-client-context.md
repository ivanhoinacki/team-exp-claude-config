---
description: Como descobrir o contexto do cliente a partir do repo, em vez de assumir
alwaysApply: true
---

# Contexto de Cliente: Descobrir, Não Assumir

__USER_NAME__ trabalha para várias empresas ao mesmo tempo. Nenhuma convenção de cliente é
padrão. Antes de agir sobre qualquer coisa específica de empresa, **derivar do repo**.

## A regra em uma linha

Se está no disco, derive. Se não está, pergunte uma vez e registre em uma linha.

Nunca escrever à mão o que o repo já responde: isso cria uma segunda fonte de verdade
que envelhece em silêncio e vira config morta.

## Descoberta: o que derivar e de onde

Na primeira ação relevante da sessão em um repo desconhecido, derivar sob demanda.
Não varrer tudo de antemão: buscar o que a tarefa exige.

| Pergunta | Fonte no repo, em ordem |
|---|---|
| Empresa / org | `git remote -v`, domínio do remote |
| Stack e runtime | `package.json`, `pyproject.toml`, `go.mod`, `*.csproj`, `Gemfile` |
| Como rodar / testar / lintar | `scripts` do manifesto, `Makefile`, `justfile`, `Taskfile` |
| Branch de integração | `git symbolic-ref refs/remotes/origin/HEAD`, `git branch -r` |
| Política de merge | `.github/` (rulesets, templates), README |
| CI e onde roda build | `.github/workflows/`, `.circleci/`, `.gitlab-ci.yml`, `azure-pipelines.yml` |
| Serviços de apoio e portas | `docker-compose*.yml`, `.env.example`, `README` |
| Convenção de commit | `git log --oneline -30`, `commitlint`, `.gitmessage` |
| Formato de ticket | prefixo nos nomes de branch (`git branch -r`) e nos commits |
| Convenção de código | arquivos vizinhos, sempre. Nunca um padrão genérico |

Derivado vale mais que lembrado. Um `AGENTS.md` de repo que contradiz o repo está
errado: o repo ganha, e a contradição vira observação para o __USER_NAME__.

## O que NÃO se descobre, e por isso se pergunta

Estes cinco não estão no código. Perguntar **uma vez**, na primeira necessidade, e
registrar em uma linha no `AGENTS.md` local do repo:

1. **Base de conhecimento**: existe wiki, RAG, pasta de docs? Consultar antes do código?
2. **Tracker**: onde vivem os tickets, e qual o formato do ID
3. **Destino de artefato**: onde gravar plano, investigação, relatório
4. **Acesso a dados**: qual comando abre staging/prod, e onde ficam as credenciais
   (pelo nome, nunca pelo valor)
5. **Quem revisa e o que trava merge**: gate de CI, aprovação obrigatória

Sem resposta ainda: seguir com o trabalho que não depende, declarar a suposição, e
perguntar no momento certo. Nunca inventar um destes cinco.

## Camada de cliente: só quando compensa

`project AGENTS.md` existe para conhecimento tribal que se repete entre
vários repos do mesmo cliente e que não está em nenhum deles. Exemplos legítimos:
mapa de microserviços, ordem de fontes de investigação, armadilha conhecida de infra.

**Não criar camada por reflexo.** Um cliente novo começa sem nenhuma. A camada nasce
quando o mesmo fato precisar ser dito pela terceira vez.

Cliente com um repo só nunca precisa de camada: o `AGENTS.md` do repo basta.

## Isolamento entre clientes

- Nunca gravar artefato, credencial ou aprendizado de um cliente na árvore de outro
- Nunca aplicar convenção de um cliente em repo de outro sem checar que é a mesma
- Fora de qualquer árvore de trabalho, permanecer neutro: não citar serviço, ticket
  ou ferramenta de cliente específico
- Na dúvida sobre qual contexto está ativo: `claude-context which`

## Declarar antes de editar

Antes da PRIMEIRA edição em um repo, junto do `repo:` e `branch:` da regra 06,
declarar o contexto resolvido:

```
repo: <path>  branch: <branch>  contexto: <slug ou neutro>
```

Trabalhando em várias empresas no mesmo dia, editar o repo certo com a convenção
errada é o modo de falha mais provável, e o mais silencioso.
