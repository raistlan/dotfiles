#!/usr/bin/env bash
# Blocking relay to the Cursor CLI: run one prompt in a fresh cursor-agent
# session, wait for it to finish, print the reply on stdout.
#
# usage: relay.sh --prompt-file FILE [--model M] [--mode ask|plan|write] [--out FILE]
set -euo pipefail

model="gpt-5.6-sol-medium"
mode="ask"
prompt_file=""
out="${TMPDIR:-/tmp}/cursor-relay.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --model)       model="$2";       shift 2 ;;
    --mode)        mode="$2";        shift 2 ;;
    --out)         out="$2";         shift 2 ;;
    -h|--help)     sed -n '2,5p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ -s "$prompt_file" ]] || { echo "--prompt-file must point at a non-empty file" >&2; exit 2; }

# --trust: -p mode cannot answer the workspace-trust prompt, so it hard-fails without this.
args=(--print --output-format text --trust --model "$model")
case "$mode" in
  ask|plan) args+=(--mode "$mode") ;;
  # Only mode that can touch the working tree; --force skips per-tool approval,
  # which -p mode cannot prompt for anyway.
  write)    args+=(--force) ;;
  *) printf 'mode must be ask, plan, or write (got %s)\n' "$mode" >&2; exit 2 ;;
esac

if cursor-agent status 2>&1 | grep -q 'Not logged in'; then
  echo "cursor-agent is not authenticated. Run: cursor-agent login" >&2
  exit 3
fi

cursor-agent "${args[@]}" "$(cat "$prompt_file")" | tee "$out"
printf '\n[reply saved to %s]\n' "$out" >&2
