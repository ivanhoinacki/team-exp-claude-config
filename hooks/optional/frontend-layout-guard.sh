#!/bin/bash
# PreToolUse on Edit/Write: injects frontend layout validation context
# only when editing style-related files. Zero cost on non-frontend edits.

input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0

inject=false
case "$file" in
  *.css|*.scss|*.styled.ts|*.styled.tsx)
    inject=true ;;
  *.tsx|*.jsx)
    old=$(echo "$input" | jq -r '.tool_input.old_string // empty')
    new=$(echo "$input" | jq -r '.tool_input.new_string // empty')
    content=$(echo "$input" | jq -r '.tool_input.content // empty')
    if echo "$old$new$content" | grep -qE 'styled\(|className=|sx=\{|style=|css`'; then
      inject=true
    fi ;;
esac

if [ "$inject" = true ]; then
  read -r -d '' ctx << 'LAYOUT'
FRONTEND LAYOUT VALIDATION: Editing style-related code.
After implementation, validate visually:
1. Playwright: screenshot at 375px (mobile), 768px (tablet), 1440px (desktop)
   browser_resize(375,812), browser_resize(768,1024), browser_resize(1440,900)
2. chrome-devtools: computed styles, box model on key elements
3. If Figma link: imugi compare + iterate until score > 95%
MCPs: mcp__playwright__*, mcp__chrome-devtools__*, mcp__imugi__*
LAYOUT
  jq -n --arg ctx "$ctx" '{ additionalContext: $ctx }'
fi

exit 0
