#!/bin/bash
# Claude Code status line - mirrors Spaceship prompt layout
# Sections: user :: dir :: git branch :: $cost :: 5h: XX% :: ctx XX%

input=$(cat)

user=$(whoami)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
short_dir=$(basename "$dir")
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Git branch (skip locks to avoid contention)
git_branch=""
if git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
fi

# Build status line with ANSI colors
# Colors: cyan=user, yellow=dir, magenta=git, green=cost, blue/yellow/red=rate, green/yellow/red=ctx
printf "\033[36m%s\033[0m" "$user"
printf " \033[2m::\033[0m "
printf "\033[33m%s\033[0m" "$short_dir"

if [ -n "$git_branch" ]; then
  printf " \033[2m::\033[0m "
  printf "\033[35m%s\033[0m" "$git_branch"
fi

# 5h rate limit with time remaining
if [ -n "$rate_5h" ]; then
  rate_int=$(printf "%.0f" "$rate_5h")
  printf " \033[2m::\033[0m "
  # Time until reset
  time_str=""
  if [ -n "$resets_at" ]; then
    now=$(date +%s)
    remaining=$((resets_at - now))
    if [ "$remaining" -gt 0 ]; then
      hours=$((remaining / 3600))
      mins=$(( (remaining % 3600) / 60 ))
      time_str=$(printf "%dh%02dm" "$hours" "$mins")
    fi
  fi
  if [ "$rate_int" -ge 80 ]; then
    printf "\033[31m%s%% %s\033[0m" "$rate_int" "$time_str"
  elif [ "$rate_int" -ge 50 ]; then
    printf "\033[33m%s%% %s\033[0m" "$rate_int" "$time_str"
  else
    printf "\033[34m%s%% %s\033[0m" "$rate_int" "$time_str"
  fi
fi

# Context window usage
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  printf " \033[2m::\033[0m "
  if [ "$used_int" -ge 80 ]; then
    printf "\033[31mctx %s%%\033[0m" "$used_int"
  elif [ "$used_int" -ge 50 ]; then
    printf "\033[33mctx %s%%\033[0m" "$used_int"
  else
    printf "\033[32mctx %s%%\033[0m" "$used_int"
  fi
fi
