#!/bin/bash
# UserPromptSubmit hook: injects LE domain context before Claude processes the prompt.
# Fires when keywords suggest Experiences, Car Hire, Orders, or Infra domains.
# Output on stdout is added to the context Claude sees. Zero cost when no match.

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty')

[ -z "$prompt" ] && exit 0

ctx=""

# Experiences / Provider / Booking domain
if echo "$prompt" | grep -qiE 'experience|rezdy|klook|derbysoft|musement|attraction|booking|provider|svc.experiences|schedule|inventory'; then
  ctx="${ctx}DOMAIN CONTEXT [Experiences]:
- Core services: svc-experiences (TypeORM/PG16:5439), svc-order (Sequelize/PG14:5436), svc-ee-offer (Salesforce Connect)
- Key patterns: query_vault(service_filter=\"svc-experiences\") for pitfalls and business rules
- Providers: Rezdy, Klook, Derbysoft, Musement. Each has its own booking flow quirks.
- Complimentary = \"bundle\" in some Slack threads (terminology alias, not same concept)
"
fi

# Car Hire domain
if echo "$prompt" | grep -qiE 'car.hire|cartrawler|vehicle|rental|svc.car.hire|fleet'; then
  ctx="${ctx}DOMAIN CONTEXT [Car Hire]:
- Core service: svc-car-hire (Prisma, BullMQ)
- Provider: CartTrawler (CT). Availability uses CT search API.
- query_vault(service_filter=\"svc-car-hire\") for integration patterns
"
fi

# Orders / Payments / Refunds domain
if echo "$prompt" | grep -qiE 'order|refund|payment|checkout|promo|voucher|discount|svc.order|booking.ref'; then
  ctx="${ctx}DOMAIN CONTEXT [Orders/Payments]:
- Core service: svc-order (Sequelize/PG14). Owns booking lifecycle.
- Refund rules: Business-Rules/Refunds in vault. Non-trivial, always query_vault first.
- Promo split: promoAmount must match everywhere in the chain (svc-order, svc-experiences, svc-ee-offer)
- query_vault(service_filter=\"svc-order\") for pitfalls
"
fi

# Whitelabel / LED domain
if echo "$prompt" | grep -qiE 'whitelabel|white.label|led|lux.everyday|svc.ee.offer|salesforce.connect|brand'; then
  ctx="${ctx}DOMAIN CONTEXT [Whitelabel/LED]:
- LED = Lux Everyday = svc-ee-offer = Salesforce Connect (all aliases for same thing)
- Data flows through svc-ee-offer before reaching Salesforce
- query_vault(service_filter=\"svc-ee-offer\") for sync and offer patterns
"
fi

# Infrastructure / Pulumi / AWS domain
if echo "$prompt" | grep -qiE 'pulumi|infra|aws|ecs|rds|s3|lambda|deploy|env.var|secret|migration|k8s'; then
  ctx="${ctx}DOMAIN CONTEXT [Infra/Deploy]:
- Stack naming: staging / prod (no dev stack). Use: le pulumi config set --secret KEY --stack staging
- Private keys with \"-----\": use printf '%s' 'value' | le pulumi config set --secret KEY --stack prod
- Tunnel for DB: le-tunnel.sh -s SERVICE -d DB -m ro (NEVER manual le aws postgres)
- query_vault(type_filter=[\"infrastructure\",\"ci-infra\"]) for deploy patterns
"
fi

if [ -n "$ctx" ]; then
  printf '%s' "$ctx"
fi

exit 0
