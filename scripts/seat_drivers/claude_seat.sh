#!/usr/bin/env bash
# claude_seat.sh — headless panel-seat driver over `claude -p` (grok edition).
#
# Runs ONE fusion-deliberation seat (panelist, judge, or fuser) as a headless
# Claude Code call on SUBSCRIPTION auth. The prompt arrives on stdin; the
# seat's text output is written to --out.
#
# Usage:
#   claude_seat.sh --model <fable-5|opus-4.8> --effort <level> \
#                  --role <panelist|judge|fuser> --out <file> \
#                  [--gate <plan|phase|summarize>] [--run-dir <dir>]  < prompt.md
#
# Auth: subscription (`claude` login / keychain OAuth) — no API key needed.
# If ANTHROPIC_API_KEY is set it OVERRIDES subscription auth and bills the
# key instead; we warn (never printing the value) and proceed.
#
# Read-only hardening: --allowedTools "Read" + --permission-mode dontAsk —
# no file-mutating tools, anything not allowlisted is denied. (--max-turns
# DOES NOT EXIST — locally VERIFIED absent on CLI 2.1.214, 2026-07-18 — so
# the bounded() timeout is the guard against runaway agentic loops.)
#
# Exit codes: 0 seat output written · 2 usage · 3 claude CLI missing ·
#   4 call failed / timed out / empty or non-JSON output.

set -uo pipefail

MODEL="" EFFORT="high" ROLE="panelist" OUT="" GATE="" RUN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   MODEL="${2:-}"; shift 2;;
    --effort)  EFFORT="${2:-}"; shift 2;;
    --role)    ROLE="${2:-}"; shift 2;;
    --out)     OUT="${2:-}"; shift 2;;
    --gate)    GATE="${2:-}"; shift 2;;
    --run-dir) RUN_DIR="${2:-}"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[[ -n "$MODEL" && -n "$OUT" ]] || { echo "need --model and --out" >&2; exit 2; }
case "$ROLE" in panelist|judge|fuser) ;; *) echo "unknown role: $ROLE" >&2; exit 2;; esac
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 3; }

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { echo "claude CLI not found — claude-cli transport unavailable" >&2; exit 3; }

# Model roster (hard rule): fable-5 and opus-4.8 only — no -latest aliases,
# no other Anthropic models as new config values. Slug map fable-5 ->
# claude-fable-5 / opus-4.8 -> claude-opus-4-8: locally VERIFIED accepted by
# --model on CLI 2.1.214 (2026-07-18).
case "$MODEL" in
  fable-5|claude-fable-5)   CLI_MODEL="claude-fable-5";;
  opus-4.8|claude-opus-4-8) CLI_MODEL="claude-opus-4-8";;
  *) echo "model not in claude-cli roster (fable-5|opus-4.8): $MODEL" >&2; exit 2;;
esac

# Skill effort enum -> claude CLI enum (low|medium|high|xhigh|max; verified on
# CLI 2.1.214). minimal/ultra are codex-CLI-only levels.
case "$EFFORT" in
  minimal) CLI_EFFORT="low";;
  ultra)   CLI_EFFORT="max";;
  low|medium|high|xhigh|max) CLI_EFFORT="$EFFORT";;
  *) echo "unknown effort: $EFFORT (enum: minimal|low|medium|high|xhigh|max|ultra)" >&2; exit 2;;
esac

# Per-effort seat timeout, same ladder as adversarial_review.sh.
# macOS has no `timeout`; perl alarm is the portable bound.
case "$CLI_EFFORT" in
  xhigh|max) SEAT_TIMEOUT="${SEAT_TIMEOUT:-1800}";;
  high)      SEAT_TIMEOUT="${SEAT_TIMEOUT:-600}";;
  *)         SEAT_TIMEOUT="${SEAT_TIMEOUT:-180}";;
esac
bounded() { perl -e 'alarm shift; exec @ARGV' "$SEAT_TIMEOUT" "$@"; }

# Presence-only guard — the value itself is NEVER printed or logged.
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "WARN: ANTHROPIC_API_KEY is set — it overrides claude subscription auth for this seat and bills the API key (value not shown)" >&2
fi

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ledger() { # ledger <role> <model> <est_usd> <note>
  [[ -n "$RUN_DIR" ]] || return 0
  mkdir -p "$RUN_DIR"
  printf '{"ts":"%s","gate":"%s","role":"%s","model":"%s","est_usd":%s,"note":"%s"}\n' \
    "$STAMP" "${GATE:-?}" "$1" "$2" "$3" "$4" >> "$RUN_DIR/ledger.jsonl"
}

PROMPT_FILE=$(mktemp) RESP=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$RESP"' EXIT
cat > "$PROMPT_FILE" # prompt on stdin (argv would cap large bundles; stdin allows up to 10MB)

# Non-bare on purpose: --bare skips keychain/OAuth discovery and would demand
# an explicit ANTHROPIC_API_KEY — the opposite of subscription-seat intent.
if ! bounded "$CLAUDE_BIN" -p \
      --model "$CLI_MODEL" --effort "$CLI_EFFORT" \
      --allowedTools "Read" --permission-mode dontAsk \
      --output-format json < "$PROMPT_FILE" > "$RESP" 2>/dev/null; then
  ledger "$ROLE" "claude-cli:$CLI_MODEL" 0 "seat failed or timed out"
  echo "claude seat failed/timed out (model=$CLI_MODEL effort=$CLI_EFFORT timeout=${SEAT_TIMEOUT}s)" >&2
  exit 4
fi

# --output-format json envelope: review text in .result, spend in .total_cost_usd.
if ! jq -e '.result | type == "string" and length > 0' "$RESP" >/dev/null 2>&1; then
  ledger "$ROLE" "claude-cli:$CLI_MODEL" 0 "non-JSON or empty result"
  echo "claude seat returned non-JSON or empty result" >&2
  exit 4
fi
mkdir -p "$(dirname "$OUT")"
jq -r '.result' "$RESP" > "$OUT"
EST_USD=$(jq -r '.total_cost_usd // 0' "$RESP" 2>/dev/null); EST_USD="${EST_USD:-0}"
ledger "$ROLE" "claude-cli:$CLI_MODEL" "$EST_USD" "seat done"
exit 0
