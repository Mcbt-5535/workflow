#!/usr/bin/env bash
# Claude Code status line: model, thinking, tokens, context
input=$(cat)

IFS=$'\x01' read -r model thinking_enabled effort_level ctx_used ctx_max input_tokens output_tokens h5_pct h5_reset w7_pct w7_reset < <(
  python3 "${CLAUDE_PROJECT_DIR:-.}/.claude/statusline-parse.py" "$input"
)

# -- Model segment --
model_seg="\033[1;36m${model}\033[0m"

# -- Thinking segment --
if [ "$thinking_enabled" = "true" ]; then
  if [ -n "$effort_level" ]; then
    think_seg="\033[1;35mThinking:${effort_level}\033[0m"
  else
    think_seg="\033[1;35mThinking:on\033[0m"
  fi
else
  think_seg="\033[0;90mThinking:off\033[0m"
fi

# -- Token usage segment --
if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
  token_seg="\033[0;33mIn:${input_tokens} Out:${output_tokens}\033[0m"
else
  token_seg="\033[0;90mTokens:--\033[0m"
fi

# -- Context window segment --
# Color based on ratio: derive pct from ctx_used/ctx_max if possible
if [ -n "$ctx_used" ] && [ -n "$ctx_max" ]; then
  used_pct=$(python3 -c "
u='$ctx_used'; m='$ctx_max'
def tok(s):
    s=s.strip()
    if s.endswith('M'): return float(s[:-1])*1e6
    if s.endswith('k'): return float(s[:-1])*1e3
    return float(s)
try: print(int(tok(u)/tok(m)*100))
except: print(0)
")
  if [ "$used_pct" -ge 80 ]; then
    ctx_color="\033[1;31m"
  elif [ "$used_pct" -ge 50 ]; then
    ctx_color="\033[1;33m"
  else
    ctx_color="\033[0;32m"
  fi
  ctx_seg="${ctx_color}Ctx:${ctx_used}/${ctx_max}\033[0m"
elif [ -n "$ctx_used" ]; then
  ctx_seg="\033[0;32mCtx:${ctx_used}\033[0m"
else
  ctx_seg="\033[0;90mCtx:--\033[0m"
fi

# -- Rate limit segments --
rl_color() {
  local pct="${1%%%*}"  # strip trailing %
  if [ -n "$pct" ] && [ "$pct" -ge 80 ] 2>/dev/null; then echo "\033[1;31m"
  elif [ -n "$pct" ] && [ "$pct" -ge 50 ] 2>/dev/null; then echo "\033[1;33m"
  else echo "\033[0;32m"; fi
}
if [ -n "$h5_pct" ]; then
  h5_label="${h5_pct}"
  [ -n "$h5_reset" ] && h5_label="${h5_pct}(↻ ${h5_reset})"
  h5_seg="$(rl_color "$h5_pct")5h:${h5_label}\033[0m"
else
  h5_seg="\033[0;90m5h:--\033[0m"
fi
if [ -n "$w7_pct" ]; then
  w7_label="${w7_pct}"
  [ -n "$w7_reset" ] && w7_label="${w7_pct}(↻ ${w7_reset})"
  w7_seg="$(rl_color "$w7_pct")7d:${w7_label}\033[0m"
else
  w7_seg="\033[0;90m7d:--\033[0m"
fi

echo -e "${model_seg}  ${think_seg}  ${token_seg}  ${ctx_seg}  ${h5_seg}  ${w7_seg}"
