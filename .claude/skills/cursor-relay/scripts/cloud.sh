#!/usr/bin/env bash
# Launch (and poll) a Cursor Cloud Agent. The cloud agent runs in Cursor's own
# environment, so unlike the local `cursor-agent` relay it can create worktrees,
# start services, seed fixtures, and drive a browser.
#
# Cursor Cloud Agents API:
#   POST https://api.cursor.com/v1/agents
#   GET  https://api.cursor.com/v1/agents/{id}/runs/{runId}
#   Docs: https://cursor.com/docs/cloud-agent/api/endpoints
#
# Auth: CURSOR_API_KEY (https://cursor.com/dashboard/api), never echoed. Taken
# from the ambient env, else sourced from $CURSOR_RELAY_ENV_FILE, else
# ~/.config/cursor-relay/.env.
#
# Prereqs: a paid Cursor plan + the Cursor GitHub App installed on the repo.
#
# usage:
#   cloud.sh launch <branch> --prompt-file FILE [--repo URL] [--model M]
#   cloud.sh status <agent-id> <run-id>
#   cloud.sh wait   <agent-id> <run-id> [--timeout SEC] [--interval SEC]
set -euo pipefail

API="https://api.cursor.com/v1"
MODEL_ID="${CURSOR_RELAY_CLOUD_MODEL:-claude-sonnet-4-5}"

fail() { printf 'cloud.sh: %s\n' "$*" >&2; exit 1; }

# Load the key from a file only if it is not already in the environment.
if [ -z "${CURSOR_API_KEY:-}" ]; then
  for candidate in "${CURSOR_RELAY_ENV_FILE:-}" "$HOME/.config/cursor-relay/.env"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      set -a; . "$candidate"; set +a
      break
    fi
  done
fi

command -v jq   >/dev/null 2>&1 || fail "jq is required (brew install jq)."
command -v curl >/dev/null 2>&1 || fail "curl is required."
[ -n "${CURSOR_API_KEY:-}" ] || fail "CURSOR_API_KEY not set. Create one at https://cursor.com/dashboard/api, then export it or put it in ~/.config/cursor-relay/.env (or point CURSOR_RELAY_ENV_FILE at a file that has it)."

# The API wants an https URL. Accept whatever form the remote is configured in.
default_repo_url() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null)" || return 1
  local path
  case "$remote" in
    git@*:*)      path="${remote#git@}"; printf 'https://%s\n' "${path/://}" ;;
    ssh://git@*)  path="${remote#ssh://git@}"; printf 'https://%s\n' "$path" ;;
    https://*)    printf '%s\n' "$remote" ;;
    *)            return 1 ;;
  esac
}

# Trailing .git is stripped by the caller so each branch above stays readable.

cmd="${1:-}"; shift || true

case "$cmd" in
  launch)
    branch="${1:-}"; shift || true
    [ -n "$branch" ] || fail "usage: cloud.sh launch <branch> --prompt-file FILE [--repo URL] [--model M]"
    prompt_file=""; repo_url="${CURSOR_RELAY_REPO_URL:-}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --prompt-file) prompt_file="$2"; shift 2 ;;
        --repo)        repo_url="$2";    shift 2 ;;
        --model)       MODEL_ID="$2";    shift 2 ;;
        *) fail "unknown option: $1" ;;
      esac
    done
    [ -s "$prompt_file" ] || fail "--prompt-file must point at a non-empty file"
    [ -n "$repo_url" ] || repo_url="$(default_repo_url)" && repo_url="${repo_url%.git}" || fail "could not derive the repo URL from 'git remote get-url origin'. Pass --repo https://github.com/<org>/<repo>."

    payload="$(jq -n \
      --arg text  "$(cat "$prompt_file")" \
      --arg url   "$repo_url" \
      --arg ref   "$branch" \
      --arg model "$MODEL_ID" \
      '{prompt:{text:$text}, model:{id:$model}, repos:[{url:$url, startingRef:$ref}], autoCreatePR:false}')"

    resp="$(curl -sS -X POST "$API/agents" \
      -H "Authorization: Bearer $CURSOR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$payload")"

    # Current API nests under {agent:{...}, run:{...}}; older shapes were flat.
    agent_id="$(echo "$resp" | jq -r '.agent.id // .id // empty')"
    [ -n "$agent_id" ] || fail "launch failed — Cursor response: $resp"
    echo "agentId=$agent_id"
    echo "runId=$(echo "$resp" | jq -r '.run.id // .agent.latestRunId // .runs[0].id // .runId // empty')"
    echo "url=$(echo "$resp" | jq -r '.agent.url // .url // .runs[0].url // empty')"
    echo "repo=$repo_url"
    echo "startingRef=$branch"
    ;;

  status)
    agent_id="${1:-}"; run_id="${2:-}"
    [ -n "$agent_id" ] && [ -n "$run_id" ] || fail "usage: cloud.sh status <agent-id> <run-id>"
    curl -sS "$API/agents/$agent_id/runs/$run_id" \
      -H "Authorization: Bearer $CURSOR_API_KEY" \
      | jq '{status, durationMs, prUrl: (.git.branches[0].prUrl // null), result}'
    ;;

  wait)
    agent_id="${1:-}"; run_id="${2:-}"; shift 2 2>/dev/null || fail "usage: cloud.sh wait <agent-id> <run-id> [--timeout SEC] [--interval SEC]"
    timeout=1800; interval=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --timeout)  timeout="$2"; shift 2 ;;
        --interval) interval="$2"; shift 2 ;;
        *) fail "unknown option: $1" ;;
      esac
    done
    elapsed=0
    while :; do
      body="$(curl -sS "$API/agents/$agent_id/runs/$run_id" -H "Authorization: Bearer $CURSOR_API_KEY")"
      state="$(echo "$body" | jq -r '.status // "UNKNOWN"')"
      case "$state" in
        FINISHED|ERROR|CANCELLED|FAILED|EXPIRED)
          printf 'status=%s after %ss\n\n' "$state" "$elapsed" >&2
          echo "$body" | jq -r '.result // "(no result text returned)"'
          [ "$state" = "FINISHED" ] || exit 4
          exit 0
          ;;
      esac
      [ "$elapsed" -ge "$timeout" ] && { printf 'still %s after %ss — giving up waiting (the run continues; poll with: cloud.sh status %s %s)\n' "$state" "$elapsed" "$agent_id" "$run_id" >&2; exit 5; }
      sleep "$interval"; elapsed=$((elapsed + interval))
    done
    ;;

  *)
    fail "usage: cloud.sh {launch <branch> --prompt-file FILE [--repo URL] [--model M] | status <agent-id> <run-id> | wait <agent-id> <run-id> [--timeout SEC] [--interval SEC]}"
    ;;
esac
