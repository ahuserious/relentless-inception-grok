#!/usr/bin/env bash
# check_prereqs.sh — preflight for /relentless-inception runs (grok edition).
#
# Probes the gate provider ladder LIVE (v0.1 checked flag presence, not
# validity — and its shipped codex flags didn't exist on the installed CLI).
# Writes a capability report to
# ~/.claude/relentless-inception-grok/gate_capability.json that
# adversarial_review.sh uses to pick the highest live rung.
#
# Transports probed:
#   grok CLI     host orchestrator (Grok Build). Feature-detected only —
#                UNKNOWN-safe, never fatal.
#   claude-cli   headless `claude -p` on Claude subscription (cheap live ping).
#   codex        codex CLI on ChatGPT subscription: models sol | luna | terra
#                (gpt-5.6 family; the skill owns the alias map — bare names
#                are not codex aliases) at ANY effort level (codex validates
#                lazily, so only a live probe proves a pair works).
#   xai / openai / anthropic / openrouter — provider-direct HTTP, probed only
#                when the backend is enabled in the fusion config AND its key
#                is present (presence-only ping; values never printed).
#
# Env: CODEX_PROBE=0 / CLAUDE_PROBE=0 skip the live subscription probes;
#      CODEX_EFFORT=<level> sets the codex probe effort (default xhigh);
#      CODEX_BIN / CLAUDE_BIN / GROK_BIN override binaries (shims exist on
#      some hosts — cmux bundles a grok shim, for example).

set -uo pipefail

FAIL=0; WARN=0
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
plain()  { printf '%s\n' "$*"; }
ok()   { green  "  OK   $*"; }
miss() { red    "  FAIL $*"; FAIL=$((FAIL+1)); }
warn() { yellow "  WARN $*"; WARN=$((WARN+1)); }

STATE_DIR="${RELENTLESS_INCEPTION_HOME:-$HOME/.claude/relentless-inception-grok}"
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
  local name="$1" raw=""
  if [[ -n "${!name:-}" ]]; then printf '%s' "${!name}"; return; fi
  # first-equals-only split (values may contain '='), then strip one layer
  # of surrounding quotes.
  if [[ -f "$SECRETS_FILE" ]] && grep -qE "^${name}=." "$SECRETS_FILE" 2>/dev/null; then
    raw=$(sed -n "s/^${name}=//p" "$SECRETS_FILE" | head -1)
  else
    raw=$(sed -n "s/^${name}=//p" "$HOME/.claude/.env" 2>/dev/null | head -1)
  fi
  raw="${raw#\"}"; raw="${raw%\"}"; raw="${raw#\'}"; raw="${raw%\'}"
  printf '%s' "$raw"
}
# Fusion config: user copy wins over the shipped default.
FUSION_CONFIG="$STATE_DIR/fusion.config.json"
[[ -f "$FUSION_CONFIG" ]] || FUSION_CONFIG="$(cd "$(dirname "$0")/.." && pwd)/assets/fusion.config.default.json"

plain "Tools (required):"
for cli in docker jq git python3 curl perl; do
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
plain "Host: grok CLI (Grok Build orchestrator)"
# Prefer a real install over per-app shims (cmux bundles one). The install
# location of x.ai/cli/install.sh is not pinned in docs — feature-detect.
if [[ -z "${GROK_BIN:-}" ]]; then
  for cand in "$HOME/.grok/bin/grok" /opt/homebrew/bin/grok /usr/local/bin/grok; do
    if [[ -x "$cand" ]]; then GROK_BIN="$cand"; break; fi
  done
fi
GROK_BIN="${GROK_BIN:-grok}"
GROK_CLI="absent"
if command -v "$GROK_BIN" >/dev/null 2>&1; then
  GROK_VERSION=$("$GROK_BIN" --version 2>/dev/null | head -1)
  GROK_CLI="present"
  ok "grok CLI found: ${GROK_VERSION:-version unknown} ($(command -v "$GROK_BIN"))"
  # Presence-only auth hint — the file is never read. ~/.grok/auth.json is the
  # documented credential cache; its absence is NOT proof of logged-out state
  # (XAI_API_KEY fallback and non-default GROK_HOME both exist) — UNKNOWN-safe.
  if [[ -f "$HOME/.grok/auth.json" ]]; then
    GROK_CLI="present-auth"; ok "grok auth cache present (~/.grok/auth.json — not read)"
  else
    warn "no ~/.grok/auth.json — run 'grok login' (or set XAI_API_KEY) before host-run grok seats"
  fi
else
  warn "grok CLI not found — this skill expects Grok Build as the host; headless transports still work"
fi

plain ""
plain "Transport: claude-cli (headless claude -p, Claude subscription)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_CLI="absent"; CLAUDE_VERSION=""
if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  CLAUDE_VERSION=$("$CLAUDE_BIN" --version 2>/dev/null | head -1)
  # Presence-only: an API key would OVERRIDE subscription auth (never printed).
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] && warn "ANTHROPIC_API_KEY is set — claude -p will bill the key, not the subscription (value not shown)"
  if [[ "${CLAUDE_PROBE:-1}" == "1" ]]; then
    # Cheap login ping: default model, no tools, JSON out. 120s bound.
    if perl -e 'alarm 120; exec @ARGV' "$CLAUDE_BIN" -p "Reply OK" \
         --output-format json --allowedTools "" --permission-mode dontAsk >/dev/null 2>&1; then
      CLAUDE_CLI="ok"; ok "claude -p ping OK ($CLAUDE_VERSION)"
    else
      CLAUDE_CLI="probe-failed"; warn "claude installed but -p ping failed — logged out? (claude auth login)"
    fi
  else
    CLAUDE_CLI="unprobed"; warn "CLAUDE_PROBE=0 — claude-cli unprobed; gate-time failures will degrade"
  fi
else
  warn "claude CLI not found — claude-cli seats/judge/fuser fall back to the grok host"
fi

plain ""
plain "Gate ladder — rung 1: openrouter-fusion"
RUNG1="absent"
if have_key OPENROUTER_API_KEY; then
  # Key travels via a chmod-600 header file, never argv — same technique as
  # probe_provider below.
  hdr=$(mktemp); chmod 600 "$hdr"
  printf 'Authorization: Bearer %s\n' "$(key_value OPENROUTER_API_KEY)" > "$hdr"
  http=$(curl -sS -o /tmp/or_probe.$$ -w '%{http_code}' --max-time 30 \
    -H @"$hdr" -H 'Content-Type: application/json' \
    -d '{"model":"openrouter/fusion","plugins":[{"id":"fusion","analysis_models":["openai/gpt-5.6","anthropic/claude-opus-4.8"]}],"messages":[{"role":"user","content":"Reply OK"}],"max_tokens":8}' \
    https://openrouter.ai/api/v1/chat/completions 2>/dev/null) || http=000
  http="${http:0:3}" # curl -w prints 000 itself on failure — never concatenate
  rm -f "$hdr" /tmp/or_probe.$$
  case "$http" in
    200) RUNG1="live";       ok   "fusion probe returned 200 — rung 1 LIVE";;
    402) RUNG1="no-credits"; warn "fusion probe 402 (no credits) — rung 1 dead, gates descend to the mixed panel";;
    400) RUNG1="config-bug"; warn "fusion probe 400 — probe body no longer schema-valid; fix the probe, do NOT descend on 400s at gate time";;
    401) RUNG1="bad-key";    warn "fusion probe 401 — OPENROUTER_API_KEY invalid/rotated; rung 1 dead until the key is replaced";;
    000) RUNG1="offline";    warn "fusion probe network failure — rung 1 unknown";;
    *)   RUNG1="error-$http"; warn "fusion probe http=$http — rung 1 dead";;
  esac
else
  warn "OPENROUTER_API_KEY not present — rung 1 unavailable (NOT fatal: ladder descends)"
fi

plain ""
plain "Transport: codex (sol|luna|terra, ANY effort)"
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
      CONFIG_SEATS=$(jq -r '[.panel[]? | select(.transport=="codex") | .model] | join(" ")' "$FUSION_CONFIG" 2>/dev/null)
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
    warn "codex installed but logged out — codex transport unavailable (codex login)"
  fi
else
  warn "codex CLI not found — codex transport unavailable"
fi

plain ""
plain "Transports: provider-direct HTTP (enabled backend + key present only)"
# probe_provider <transport> <key_var> <models_url> <auth_style>
# Presence-only ping (GET models). The key travels via a chmod-600 header
# file, never argv. Note: openrouter's /models endpoint is public, so a 200
# there proves reachability, not key validity — rung 1 covers auth for it.
probe_provider() {
  local name="$1" key_var="$2" url="$3" style="$4" enabled hdr http backend_key
  # Transport name -> canonical backends.* key in the fusion config
  # (xai -> xai_direct etc.; openrouter is already canonical).
  case "$name" in
    xai)       backend_key="xai_direct";;
    openai)    backend_key="openai_direct";;
    anthropic) backend_key="anthropic_direct";;
    *)         backend_key="$name";;
  esac
  enabled=$(jq -r --arg t "$name" --arg bk "$backend_key" \
    '(([.panel[]?.transport] + [.judge.transport?, .fuser.transport?]) | index($t) != null)
     or ((.backends // {})[$bk] // false)' "$FUSION_CONFIG" 2>/dev/null)
  if [[ "$enabled" != "true" ]]; then echo disabled; return; fi
  if ! have_key "$key_var"; then echo no-key; return; fi
  hdr=$(mktemp); chmod 600 "$hdr"
  if [[ "$style" == "anthropic" ]]; then
    printf 'x-api-key: %s\nanthropic-version: 2023-06-01\n' "$(key_value "$key_var")" > "$hdr"
  else
    printf 'Authorization: Bearer %s\n' "$(key_value "$key_var")" > "$hdr"
  fi
  http=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 -H @"$hdr" "$url" 2>/dev/null) || http=000
  http="${http:0:3}" # curl -w prints 000 itself on failure — never concatenate
  rm -f "$hdr"
  case "$http" in
    200)     echo ok;;
    401|403) echo bad-key;;
    000)     echo offline;;
    *)       echo "error-$http";;
  esac
}
report_provider() { # report_provider <transport> <key_var> <status>
  case "$3" in
    ok)       ok   "$1: models ping OK ($2 present)";;
    disabled) plain "  --   $1: not referenced in fusion config — skipped";;
    no-key)   warn "$1: backend enabled but $2 not present — seats will fail at gate time";;
    bad-key)  warn "$1: $2 rejected (401/403) — rotate the key";;
    offline)  warn "$1: network failure — status unknown";;
    *)        warn "$1: probe returned $3";;
  esac
}
PROV_XAI=$(probe_provider xai XAI_API_KEY "https://api.x.ai/v1/models" bearer)
report_provider xai XAI_API_KEY "$PROV_XAI"
PROV_OPENAI=$(probe_provider openai OPENAI_API_KEY "https://api.openai.com/v1/models" bearer)
report_provider openai OPENAI_API_KEY "$PROV_OPENAI"
# anthropic: HEAD-style minimal request — GET /v1/models?limit=1, body discarded.
PROV_ANTHROPIC=$(probe_provider anthropic ANTHROPIC_API_KEY "https://api.anthropic.com/v1/models?limit=1" anthropic)
report_provider anthropic ANTHROPIC_API_KEY "$PROV_ANTHROPIC"
PROV_OPENROUTER=$(probe_provider openrouter OPENROUTER_API_KEY "https://openrouter.ai/api/v1/models" bearer)
report_provider openrouter OPENROUTER_API_KEY "$PROV_OPENROUTER"

plain ""
plain "Gate ladder — rung 3: grok-panel"
ok "always available inside Grok Build (4 personas + cheap judge + strong fuser; stamped degraded)"

plain ""
plain "Skill bundle:"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
for f in SKILL.md scripts/adversarial_review.sh scripts/relentless_relay.sh \
         scripts/stall_watchdog.sh scripts/status_line.sh scripts/install_hooks.sh \
         scripts/seat_drivers/claude_seat.sh scripts/seat_drivers/http_seat.sh \
         agents/planner.md agents/dev-worker.md agents/adversarial-review.md \
         references/adversarial-gates.md assets/verdict.schema.json; do
  if [[ -f "$SKILL_DIR/$f" ]]; then ok "$f"; else miss "$f missing — re-install the skill bundle"; fi
done

plain ""
plain "Run state:"
[[ -f "$STATE_DIR/KILL" ]] && warn "KILL switch set at $STATE_DIR/KILL — remove before running"

# Capability report for adversarial_review.sh --backend=auto.
jq -n --arg rung1 "$RUNG1" --arg grokcli "$GROK_CLI" --arg claudecli "$CLAUDE_CLI" \
  --arg claudev "${CLAUDE_VERSION:-}" \
  --arg sol "$SEAT_SOL" --arg luna "$SEAT_LUNA" --arg terra "$SEAT_TERRA" \
  --arg v "$CODEX_VERSION" --arg login "$LOGIN" \
  --arg xai "$PROV_XAI" --arg openai "$PROV_OPENAI" \
  --arg anthropic "$PROV_ANTHROPIC" --arg openrouter "$PROV_OPENROUTER" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema:"grok-v1", rung1:$rung1,
    grok_cli:$grokcli,
    claude_cli:$claudecli, claude_version:(if $claudev=="" then null else $claudev end),
    codex:{login:$login, sol:$sol, luna:$luna, terra:$terra,
           version:(if $v=="" then null else $v end)},
    providers:{xai:$xai, openai:$openai, anthropic:$anthropic, openrouter:$openrouter},
    rung3:"always", probed_at:$ts}' > "$CAPS"
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
