# Secrets

## Armazenamento

Token, API key ou senha nunca em plaintext, nunca dentro de repo, nunca em
historico de shell, nunca em resposta de chat.

Ordem: (1) macOS Keychain, `security add-generic-password -s <svc> -a <acct> -w`;
(2) arquivo `chmod 600` fora de qualquer repo. Nada alem disso.

## Receita de rotacao (4 passos, nenhum opcional)

1. Guardar no Keychain ou arquivo 600.
2. Validar contra a API real.
3. Apagar a copia insegura.
4. Confirmar que a copia sumiu.

Token validado com o original em plaintext ainda no disco NAO esta pronto.

## Nunca imprimir

Referenciar secret por nome, jamais por valor: sem `cat`, sem `echo`, sem log,
sem paste. Vale para `~/.pgpass` (RTK.md), arquivos de credencial e screenshot.
Redigir em arquivo de evidencia.

Scan de secret antes de commitar segue a regra 00.
