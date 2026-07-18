#!/usr/bin/env bash
# http_seat.sh — provider-direct HTTP panel-seat driver (grok edition).
#
# Runs ONE fusion-deliberation seat (panelist, judge, or fuser) as a single
# chat call against a provider's own API. The prompt arrives on stdin; the
# seat's text output is written to --out.
#
# Usage:
#   http_seat.sh --provider <xai|openai|anthropic|openrouter> --model <slug> \
#                --effort <level> --role <panelist|judge|fuser> --out <file> \
#                [--gate <plan|phase|summarize>] [--run-dir <dir>]  < prompt.md
#
# Transports:
#   xai / openai / openrouter — OpenAI-compatible POST <base>/chat/completions
#     with reasoning_effort. VERIFIED live 2026-07-18: api.x.ai model grok-4.5
#     accepts reasoning_effort "xhigh" (200; reasoning_tokens present).
#   anthropic — POST https://api.anthropic.com/v1/messages with x-api-key +
#     anthropic-version headers; max_tokens required. Effort mapping isolated
#     in anthropic_effort() below.
#
# Keys are read ONLY by name from env, ~/.claude/relentless-inception-grok/
# secrets.env, or ~/.claude/.env. Never echoed, never in argv (headers travel
# via a chmod-600 temp file). curl writes to a temp file; 429/5xx/network
# failures are retried twice with backoff.
#
# Exit codes: 0 seat output written · 2 usage · 3 missing tooling or key ·
#   4 call failed after retries / empty output.

set -uo pipefail

PROVIDER="" MODEL="" EFFORT="high" ROLE="panelist" OUT="" GATE="" RUN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="${2:-}"; shift 2;;
    --model)    MODEL="${2:-}"; shift 2;;
    --effort)   EFFORT="${2:-}"; shift 2;;
    --role)     ROLE="${2:-}"; shift 2;;
    --out)      OUT="${2:-}"; shift 2;;
    --gate)     GATE="${2:-}"; shift 2;;
    --run-dir)  RUN_DIR="${2:-}"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[[ -n "$PROVIDER" && -n "$MODEL" && -n "$OUT" ]] || { echo "need --provider --model --out" >&2; exit 2; }
case "$ROLE" in panelist|judge|fuser) ;; *) echo "unknown role: $ROLE" >&2; exit 2;; esac
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 3; }
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 3; }

case "$PROVIDER" in
  xai)        BASE_URL="https://api.x.ai/v1";          KEY_VAR="XAI_API_KEY";;
  openai)     BASE_URL="https://api.openai.com/v1";    KEY_VAR="OPENAI_API_KEY";;
  openrouter) BASE_URL="https://openrouter.ai/api/v1"; KEY_VAR="OPENROUTER_API_KEY";;
  anthropic)  BASE_URL="https://api.anthropic.com/v1"; KEY_VAR="ANTHROPIC_API_KEY";;
  *) echo "unknown provider: $PROVIDER (enum: xai|openai|anthropic|openrouter)" >&2; exit 2;;
esac

case "$EFFORT" in minimal|low|medium|high|xhigh|max|ultra) ;; *)
  echo "unknown effort: $EFFORT" >&2; exit 2;; esac

# ---- key lookup: env var -> skill secrets.env -> ~/.claude/.env (value never printed)
STATE_DIR="${RELENTLESS_INCEPTION_HOME:-$HOME/.claude/relentless-inception-grok}"
SECRETS_FILE="$STATE_DIR/secrets.env"
KEY=""
if [[ -n "${!KEY_VAR:-}" ]]; then
  KEY="${!KEY_VAR}"
elif [[ -f "$SECRETS_FILE" ]] && grep -qE "^${KEY_VAR}=." "$SECRETS_FILE" 2>/dev/null; then
  KEY=$(sed -n "s/^${KEY_VAR}=//p" "$SECRETS_FILE" | head -1)
elif [[ -f "$HOME/.claude/.env" ]] && grep -qE "^${KEY_VAR}=." "$HOME/.claude/.env" 2>/dev/null; then
  KEY=$(sed -n "s/^${KEY_VAR}=//p" "$HOME/.claude/.env" | head -1)
fi
# first-equals-only split (values may contain '='); strip one layer of
# surrounding quotes.
KEY="${KEY#\"}"; KEY="${KEY%\"}"; KEY="${KEY#\'}"; KEY="${KEY%\'}"
[[ -n "$KEY" ]] || { echo "$KEY_VAR unavailable — set it in env or $SECRETS_FILE" >&2; exit 3; }

# Per-effort seat timeout, same ladder as adversarial_review.sh.
case "$EFFORT" in
  xhigh|max|ultra) SEAT_TIMEOUT="${SEAT_TIMEOUT:-1800}";;
  high)            SEAT_TIMEOUT="${SEAT_TIMEOUT:-600}";;
  *)               SEAT_TIMEOUT="${SEAT_TIMEOUT:-180}";;
esac

# OpenAI-compatible reasoning_effort: pass the skill level through verbatim —
# the server validates (verified above for xai xhigh). xhigh is the verified
# wire ceiling: "ultra" (codex-CLI-only) and "max" both map down to it.
openai_compat_effort() {
  case "$1" in ultra|max) echo "xhigh";; *) echo "$1";; esac
}

# Anthropic effort mapping — keep ALL Anthropic-specific knob logic here.
# Current Messages API (fable-5 / opus-4.8): reasoning depth is
# output_config.effort with enum low|medium|high|xhigh|max (GA, no beta
# header). thinking budget_tokens is REMOVED (400 if sent); the on-mode is
# thinking {"type":"adaptive"}, explicitly accepted on both roster models.
# Skill levels outside the enum: minimal->low, ultra->max.
anthropic_effort() {
  case "$1" in minimal) echo "low";; ultra) echo "max";; *) echo "$1";; esac
}

# Anthropic model roster (hard rule): fable-5 and opus-4.8 only.
if [[ "$PROVIDER" == "anthropic" ]]; then
  case "$MODEL" in
    fable-5|claude-fable-5)   API_MODEL="claude-fable-5";;
    opus-4.8|claude-opus-4-8) API_MODEL="claude-opus-4-8";;
    *) echo "model not in anthropic roster (fable-5|opus-4.8): $MODEL" >&2; exit 2;;
  esac
else
  API_MODEL="$MODEL"
fi

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ledger() { # ledger <role> <model> <est_usd> <note>
  [[ -n "$RUN_DIR" ]] || return 0
  mkdir -p "$RUN_DIR"
  printf '{"ts":"%s","gate":"%s","role":"%s","model":"%s","est_usd":%s,"note":"%s"}\n' \
    "$STAMP" "${GATE:-?}" "$1" "$2" "$3" "$4" >> "$RUN_DIR/ledger.jsonl"
}

PROMPT_FILE=$(mktemp) BODY_FILE=$(mktemp) HDR_FILE=$(mktemp) RESP=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$BODY_FILE" "$HDR_FILE" "$RESP"' EXIT
chmod 600 "$HDR_FILE"
cat > "$PROMPT_FILE" # prompt on stdin

if [[ "$PROVIDER" == "anthropic" ]]; then
  ENDPOINT="messages"
  # Headers via file (-H @file) so the key never appears in argv/ps.
  printf 'x-api-key: %s\nanthropic-version: 2023-06-01\ncontent-type: application/json\n' \
    "$KEY" > "$HDR_FILE"
  # max_tokens is REQUIRED; 16000 keeps non-streaming under HTTP timeouts.
  jq -n --rawfile prompt "$PROMPT_FILE" --arg model "$API_MODEL" \
    --arg effort "$(anthropic_effort "$EFFORT")" \
    '{model:$model, max_tokens:16000,
      thinking:{type:"adaptive"},
      output_config:{effort:$effort},
      messages:[{role:"user", content:$prompt}]}' > "$BODY_FILE"
else
  ENDPOINT="chat/completions"
  printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$KEY" > "$HDR_FILE"
  jq -n --rawfile prompt "$PROMPT_FILE" --arg model "$API_MODEL" \
    --arg effort "$(openai_compat_effort "$EFFORT")" \
    '{model:$model, reasoning_effort:$effort,
      messages:[{role:"user", content:$prompt}]}' > "$BODY_FILE"
fi

# One call + up to 2 retries on 429/5xx/network failure, with backoff.
HTTP=000; attempt=0
for backoff in 5 15 0; do
  HTTP=$(curl -sS -o "$RESP" -w '%{http_code}' --max-time "$SEAT_TIMEOUT" \
    -H @"$HDR_FILE" -d @"$BODY_FILE" "$BASE_URL/$ENDPOINT" 2>/dev/null) || HTTP=000
  HTTP="${HTTP:0:3}" # curl -w prints 000 itself on failure — never concatenate
  attempt=$((attempt+1))
  case "$HTTP" in
    429|5??|000)
      if [[ "$attempt" -le 2 ]]; then
        echo "seat http=$HTTP (attempt $attempt) — retry in ${backoff}s" >&2
        sleep "$backoff"
        continue
      fi
      ;;
  esac
  break
done

if [[ "$HTTP" != "200" ]]; then
  ledger "$ROLE" "$PROVIDER:$API_MODEL" 0 "http-$HTTP after $attempt attempt(s)"
  echo "seat failed: $PROVIDER $API_MODEL http=$HTTP after $attempt attempt(s)" >&2
  exit 4
fi

# Extract the seat's text. Response bodies never contain the key — but keep
# them out of the transcript anyway (only $OUT gets written).
mkdir -p "$(dirname "$OUT")"
if [[ "$PROVIDER" == "anthropic" ]]; then
  STOP_REASON=$(jq -r '.stop_reason // ""' "$RESP" 2>/dev/null)
  if [[ "$STOP_REASON" == "refusal" ]]; then
    ledger "$ROLE" "$PROVIDER:$API_MODEL" 0 "stop_reason=refusal"
    echo "seat refused (stop_reason=refusal)" >&2
    exit 4
  fi
  jq -r '[.content[]? | select(.type=="text") | .text] | join("\n")' "$RESP" > "$OUT" 2>/dev/null
else
  jq -r '.choices[0].message.content // empty' "$RESP" > "$OUT" 2>/dev/null
fi

if [[ ! -s "$OUT" ]]; then
  ledger "$ROLE" "$PROVIDER:$API_MODEL" 0 "empty completion"
  echo "seat returned an empty completion" >&2
  exit 4
fi
ledger "$ROLE" "$PROVIDER:$API_MODEL" 0 "http-200; reconcile est_usd via provider billing"
exit 0
