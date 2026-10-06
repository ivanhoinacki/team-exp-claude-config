# Debug: Evidencia Antes de Editar

Vale sempre. Nao depende de skill.

## Ordem obrigatoria

1. Reproduzir e capturar evidencia crua (request/response, status HTTP, log,
   estado do token, linha do banco).
2. Declarar a hipotese E o unico teste que a refutaria.
3. Rodar esse teste.
4. So entao editar.

Nenhuma edicao antes do passo 3. Duas hipoteses falhadas = parar, conforme
"falha em cascata" da regra 03: findings em arquivo, reportar, perguntar.

## Bugs de auth/login (regra dura)

NUNCA resetar senha, rotacionar token ou criar mock de login como passo de
diagnostico. Isso destroi a evidencia e altera o sistema sob teste.

Capturar primeiro:

- status HTTP + body da resposta
- qual host/porta/ambiente foi realmente atingido
- se o token foi enviado, e como o servidor respondeu
- case do username (varios sistemas tratam username como case-sensitive)

Causa raiz tipica e host de ambiente errado ou case do usuario, nao credencial
ruim.

## Sucesso exige prova

Nao declarar corrigido sem colar a saida real do teste que passou. Build verde
nao e prova de comportamento.
