#!/bin/bash
# CwdChanged hook: fires when Claude changes working directory.
# Detects LE service directories and injects relevant service context.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
prev=$(echo "$input" | jq -r '.previous_cwd // ""')

[ -z "$cwd" ] && exit 0
[ "$cwd" = "$prev" ] && exit 0

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG="/tmp/claude-events-${PPID}.jsonl"

jq -n --arg ts "$ts" --arg cwd "$cwd" --arg prev "$prev" \
  '{timestamp: $ts, event: "CwdChanged", cwd: $cwd, previous_cwd: $prev}' \
  >> "$LOG" 2>/dev/null

ctx=""

case "$cwd" in
  */svc-experiences*|*/svc-experiences--*)
    ctx="CWD CONTEXT [svc-experiences]: TypeScript, TypeORM, PostgreSQL (port 5439).
Stack: Node.js + Express + BullMQ. DB tunnel: le-tunnel.sh -s svc-experiences -d svc_experiences -m ro
query_vault(service_filter=\"svc-experiences\") for pitfalls and provider patterns."
    ;;
  */svc-order*|*/svc-order--*)
    ctx="CWD CONTEXT [svc-order]: TypeScript, Sequelize, PostgreSQL (port 5436).
Owns booking lifecycle, payments, refunds. DB tunnel: le-tunnel.sh -s svc-order -d svc_order -m ro
query_vault(service_filter=\"svc-order\") for refund/promo business rules."
    ;;
  */svc-car-hire*|*/svc-car-hire--*)
    ctx="CWD CONTEXT [svc-car-hire]: TypeScript, Prisma, BullMQ. Provider: CartTrawler (CT).
query_vault(service_filter=\"svc-car-hire\") for integration patterns."
    ;;
  */svc-ee-offer*|*/svc-ee-offer--*)
    ctx="CWD CONTEXT [svc-ee-offer]: Salesforce Connect / LED / Lux Everyday (all aliases).
Syncs offer data to Salesforce. query_vault(service_filter=\"svc-ee-offer\") for sync patterns."
    ;;
  */www-le-customer*|*/www-le-customer--*)
    ctx="CWD CONTEXT [www-le-customer]: Next.js customer-facing frontend.
query_vault(service_filter=\"www-le-customer\") for frontend patterns and gotchas."
    ;;
  */www-ee-admin*|*/www-ee-admin--*)
    ctx="CWD CONTEXT [www-ee-admin]: React admin panel for Experiences.
query_vault(service_filter=\"www-ee-admin\") for admin UI patterns."
    ;;
  */infra-le*|*/infra-le--*)
    ctx="CWD CONTEXT [infra-le]: Pulumi infrastructure. Stack: staging / prod (no dev stack).
Secrets: le pulumi config set --secret KEY --stack staging
Tunnel: le-tunnel.sh (NEVER le aws postgres directly)."
    ;;
esac

[ -n "$ctx" ] && jq -n --arg ctx "$ctx" '{ additionalContext: $ctx }'

exit 0
