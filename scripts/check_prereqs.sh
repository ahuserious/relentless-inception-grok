#!/usr/bin/env bash
# check_prereqs.sh — v0.2 preflight for /relentless-inception runs.
#
# Probes the gate provider ladder LIVE (v0.1 checked flag presence, not
# validity — and its shipped codex flags didn't exist on the installed CLI).
# Writes a capability report to ~/.claude/relentless-inception/gate_capability.json
# that adversarial_review.sh uses to pick the highest live rung.
#
# Codex prerequisite (rung 2): models sol | luna | terra (the gpt-5.6 family;
# the skill owns the alias map — bare names are not codex aliases) at ANY
# effort level (minimal|low|medium|high|xhigh|ultra — full CLI enum; codex
# validates lazily, so only a live probe proves a pair works).
#
# Env: CODEX_PROBE=0 skips live codex probes (offline preflight);
#      CODEX_EFFORT=<level> sets the probe effort (default xhigh);
#      CODEX_BIN=<path> overrides the codex binary (shims exist on some hosts).

set -uo pipefail

FAIL=0; WARN=0
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
plain()  { printf '%s\n' "$*"; }
ok()   { green  "  OK   $*"; }
miss() { red    "  FAIL $*"; FAIL=$((FAIL+1)); }
warn() { yellow "  WARN $*"; WARN=$((WARN+1)); }

STATE_DIR="$HOME/.claude/relentless-inception"
mkdir -p "$STATE_DIR"
CAPS="$STATE_DIR/gate_capability.json"

# env var OR the skill secrets file OR a line in ~/.claude/.env (value never printed).
SECRETS_FILE="$STATE_DIR/secrets.env"
have_key() {
  local name="$1"
  [[ -n "${!name:-}" ]] && return 0
  [[ -f "$SECRETS_FILE" ]] && grep -qE "^${name}=." "$SECRETS_FILE" 2>/dev/null && return 0
  [[ -f "$HOME/.claude/.env" ]] && grep -q "^${name}=" "$HOME/.claude/.env" 2>/dev/null
}
key_value() { # for probes only — never echoed
  local name="$1"
  if [[ -n "${!name:-}" ]]; then printf '%s' "${!name}"; return; fi
  if [[ -f "$SECRETS_FILE" ]] && grep -qE "^${name}=." "$SECRETS_FILE" 2>/dev/null; then
    awk -F= "/^${name}=/{print \$2; exit}" "$SECRETS_FILE"; return
  fi
  awk -F= "/^${name}=/{print \$2; exit}" "$HOME/.claude/.env" 2>/dev/null
}
# Fusion config: user copy wins over the shipped default.
FUSION_CONFIG="$STATE_DIR/fusion.config.json"
[[ -f "$FUSION_CONFIG" ]] || FUSION_CONFIG="$(cd "$(dirname "$0")/.." && pwd)/assets/fusion.config.default.json"

plain "Tools (required):"
for cli in codex docker jq git python3 curl perl; do
  if command -v "$cli" >/dev/null 2>&1; then ok "$cli ($(command -v "$cli"))"
  else miss "$cli not found — install per references/prereqs.md"; fi
done

plain ""
plain "Tools (optional — reduced features, NOT fatal):"
for cli in uv dagger tmux; do
  if command -v "$cli" >/dev/null 2>&1; then ok "$cli"
  else warn "$cli not found — the matching shipping/relay features degrade (recorded, not fatal)"; fi
done

plain ""
plain "Gate ladder — rung 1: openrouter-fusion"
RUNG1="absent"
if have_key OPENROUTER_API_KEY; then
  http=$(curl -sS -o /tmp/or_probe.$$ -w '%{http_code}' --max-time 30 \
    -H "Authorization: Bearer $(key_value OPENROUTER_API_KEY)" -H 'Content-Type: application/json' \
    -d '{"model":"openrouter/fusion","plugins":[{"id":"fusion","analysis_models":["openai/gpt-5.6","anthropic/claude-opus-4.8"]}],"messages":[{"role":"user","content":"Reply OK"}],"max_tokens":8}' \
    https://openrouter.ai/api/v1/chat/completions 2>/dev/null || echo 000)
  rm -f /tmp/or_probe.$$
  case "$http" in
    200) RUNG1="live";       ok   "fusion probe returned 200 — rung 1 LIVE";;
    402) RUNG1="no-credits"; warn "fusion probe 402 (no credits) — rung 1 dead, gates descend to codex";;
    400) RUNG1="config-bug"; warn "fusion probe 400 — probe body no longer schema-valid; fix the probe, do NOT descend on 400s at gate time";;
    401) RUNG1="bad-key";    warn "fusion probe 401 — OPENROUTER_API_KEY invalid/rotated; rung 1 dead until the key is replaced";;
    000) RUNG1="offline";    warn "fusion probe network failure — rung 1 unknown";;
    *)   RUNG1="error-$http"; warn "fusion probe http=$http — rung 1 dead";;
  esac
else
  warn "OPENROUTER_API_KEY not present — rung 1 unavailable (NOT fatal: ladder descends)"
fi

plain ""
plain "Gate ladder — rung 2: codex panel (sol|luna|terra, ANY effort)"
# Prefer the real binary over per-app shims (cmux etc.).
if [[ -z "${CODEX_BIN:-}" && -x /opt/homebrew/bin/codex ]]; then CODEX_BIN=/opt/homebrew/bin/codex; fi
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_VERSION=""; LOGIN="logged-out"
# macOS ships bash 3.2 (no associative arrays) — plain vars per seat.
SEAT_SOL=unprobed; SEAT_LUNA=unprobed; SEAT_TERRA=unprobed
if command -v "$CODEX_BIN" >/dev/null 2>&1; then
  CODEX_VERSION=$("$CODEX_BIN" --version 2>/dev/null | head -1)
  if "$CODEX_BIN" login status >/dev/null 2>&1; then
    LOGIN="logged-in"; ok "codex login status: logged in ($CODEX_VERSION)"
    EFFORT="${CODEX_EFFORT:-xhigh}"
    case "$EFFORT" in minimal|low|medium|high|xhigh|ultra) ;; *) miss "CODEX_EFFORT=$EFFORT not in enum"; EFFORT=xhigh;; esac
    if [[ "${CODEX_PROBE:-1}" == "1" ]]; then
      CONFIG_SEATS=$(jq -r '[.panel[] | select(.transport=="codex") | .model] | join(" ")' "$FUSION_CONFIG" 2>/dev/null)
      for seat in ${CONFIG_SEATS:-sol}; do
        slug="gpt-5.6-$seat"
        if perl -e 'alarm 90; exec @ARGV' "$CODEX_BIN" exec -m "$slug" \
             -c model_reasoning_effort="$EFFORT" -s read-only --skip-git-repo-check \
             --ephemeral -o /dev/null "Reply OK" >/dev/null 2>&1; then
          state=ok; ok "$seat -> $slug @ $EFFORT: live probe OK"
        else
          state=fail; warn "$seat -> $slug @ $EFFORT: probe failed (quota/rollout/effort rejection)"
        fi
        case "$seat" in sol) SEAT_SOL=$state;; luna) SEAT_LUNA=$state;; terra) SEAT_TERRA=$state;; esac
      done
    else
      warn "CODEX_PROBE=0 — seats unprobed; gate-time failures will descend"
    fi
  else
    warn "codex installed but logged out — rung 2 unavailable (codex login)"
  fi
else
  warn "codex CLI not found — rung 2 unavailable"
fi
PLUGIN_DIR=$(ls -d "$HOME/.claude/plugins/cache/openai-codex/codex/"* 2>/dev/null | sort -V | tail -1)
if [[ -n "${PLUGIN_DIR:-}" ]]; then ok "claude codex plugin: $PLUGIN_DIR (companion available)"
else warn "claude codex plugin not installed — raw CLI path only"; fi

plain ""
plain "Gate ladder — rung 3: claude-panel"
ok "always available inside Claude Code (4 personas + cheap judge + strong fuser; stamped degraded)"

plain ""
plain "Credentials (informational — gates never hard-require a specific vendor):"
have_key ANTHROPIC_API_KEY && ok "ANTHROPIC_API_KEY present" \
  || warn "ANTHROPIC_API_KEY not set — fine inside Claude Code (in-process routing)"

plain ""
plain "Skill bundle:"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
for f in SKILL.md scripts/adversarial_review.sh scripts/relentless_relay.sh \
         scripts/stall_watchdog.sh scripts/status_line.sh scripts/install_hooks.sh \
         agents/planner.md agents/dev-worker.md agents/adversarial-review.md \
         references/adversarial-gates.md assets/verdict.schema.json; do
  if [[ -f "$SKILL_DIR/$f" ]]; then ok "$f"; else miss "$f missing — re-install the skill bundle"; fi
done

plain ""
plain "Run state:"
[[ -f "$STATE_DIR/KILL" ]] && warn "KILL switch set at $STATE_DIR/KILL — remove before running"

# Capability report for adversarial_review.sh --backend=auto.
jq -n --arg rung1 "$RUNG1" --arg sol "$SEAT_SOL" --arg luna "$SEAT_LUNA" \
  --arg terra "$SEAT_TERRA" --arg v "$CODEX_VERSION" --arg login "$LOGIN" \
  --arg plugin "${PLUGIN_DIR:-}" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{rung1:$rung1, rung2:{sol:$sol, luna:$luna, terra:$terra},
    rung3:"always", codex_version:$v, codex_login:$login,
    codex_plugin:(if $plugin=="" then null else $plugin end), probed_at:$ts}' > "$CAPS"
plain ""
green "capability report: $CAPS"

plain ""
if [[ "$FAIL" -gt 0 ]]; then
  red "$FAIL fatal issue(s). Fix above before running /relentless-inception."
  exit 1
fi
[[ "$WARN" -gt 0 ]] && yellow "$WARN warning(s) — run proceeds with the ladder degrading as recorded."
green "Prereqs OK."
exit 0
