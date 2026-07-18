#!/usr/bin/env bash
# rescue.sh — pick up a rescue trigger and drive the 7-step rescue cycle.
#
# This is a STATE MACHINE — it cannot spawn LLM subagents on its own (only
# the LLM-side orchestrator can do that). What it does:
#
#   1. Claims the oldest trigger file from $RELENTLESS_INCEPTION_HOME/triggers/.
#   2. Scaffolds the rescue cycle directory.
#   3. Reads the trigger + the active run manifest + the last K session events
#      into a curated bundle, written to .../rescues/<cycle>/inputs.md.
#   4. Builds a RELENTLESS-INBOX prompt that instructs a FRESH session to
#      perform steps 1-5 of the documented rescue flow (diagnosis +
#      consortium + fusion gate + approved.md + self-improve).
#   5. Feature-detects the grok CLI. If present, dispatches the prompt as a
#      FRESH headless session (grok -p ... -s <uuid>) — fresh context is the
#      point of takeover; --resume/-r is only for the USER re-attaching to
#      that new session afterwards. If absent, stages the prompt at
#      $RELENTLESS_INCEPTION_HOME/lateral-pass/pending-relentless.md for the
#      relentless_relay.sh flow and prints the manual banner.
#
# The LLM, upon starting with the fresh context, runs steps 1-5 (calling
# adversarial_review.sh for the gates and its subagent mechanism for the
# consortium), writes approved.md, and resumes the run from the last
# checkpoint.
#
# Idempotent: rescues are tracked by trigger filename; a re-invocation with
# the same trigger file is a no-op (the file gets moved to processed/ on
# first claim).

set -euo pipefail

HOME_DIR="${RELENTLESS_INCEPTION_HOME:-$HOME/.claude/relentless-inception-grok}"
TRIGGERS="$HOME_DIR/triggers"
PROCESSED="$HOME_DIR/triggers/processed"
RUNS="$HOME_DIR/runs"
LATERAL="$HOME_DIR/lateral-pass"
INBOX="$LATERAL/pending-relentless.md"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$PROCESSED" "$LATERAL"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[rescue %s] %s\n' "$(ts)" "$*" >&2; }

# Pick the oldest unprocessed trigger.
trigger="$(ls -1tr "$TRIGGERS"/*.json 2>/dev/null | head -1 || true)"
if [[ -z "$trigger" ]]; then
  log "no trigger files in $TRIGGERS — nothing to do"
  exit 0
fi
trigger_name="$(basename "$trigger")"
log "claimed trigger: $trigger_name"

# Move it to processed/ atomically so concurrent rescue invocations don't race.
mv "$trigger" "$PROCESSED/$trigger_name"
trigger="$PROCESSED/$trigger_name"

# Figure out which run this is for. Trigger schema (per agents/background-agent.md):
# { trigger, run_id?, timestamp, detected_by, details, recommended_rescue_lead }
run_id="$(jq -r '.run_id // ""' "$trigger" 2>/dev/null || echo "")"

if [[ -z "$run_id" ]]; then
  # Fall back to most-recently-updated manifest if the trigger didn't name a run.
  manifest="$(find "$RUNS" -maxdepth 2 -name manifest.json -type f 2>/dev/null \
              | xargs -I{} stat -f "%m %N" {} 2>/dev/null \
              | sort -rn | head -1 | awk '{print $2}')"
  [[ -n "$manifest" ]] && run_id="$(jq -r '.run_id // ""' "$manifest")"
fi

if [[ -z "$run_id" ]]; then
  log "could not resolve run_id; aborting (trigger preserved at $trigger)"
  exit 1
fi
log "run_id resolved: $run_id"

run_dir="$RUNS/$run_id"
[[ -d "$run_dir" ]] || { log "run dir $run_dir not found"; exit 1; }
mkdir -p "$run_dir/rescues"

# Pick the next cycle number.
last_cycle="$(find "$run_dir/rescues" -maxdepth 1 -type d -name 'cycle-*' 2>/dev/null \
              | sed 's|.*cycle-||' | sort -n | tail -1)"
next_cycle=$(( ${last_cycle:-0} + 1 ))
cycle_dir="$run_dir/rescues/cycle-$next_cycle"
mkdir -p "$cycle_dir"
log "cycle directory: $cycle_dir"

# Pull a curated input bundle. The session log lives at the orchestrator's
# discretion; for now we grab the manifest, recent stop events, and the
# trigger itself. Future iterations can extend this.
cat > "$cycle_dir/inputs.md" <<EOF
# Rescue inputs — $run_id cycle $next_cycle

## Trigger
\`\`\`json
$(cat "$trigger")
\`\`\`

## Manifest (current state)
\`\`\`json
$(cat "$run_dir/manifest.json" 2>/dev/null || echo '{}')
\`\`\`

## Recent stop events (last 20)
\`\`\`
$(tail -20 "$run_dir/stop-events.jsonl" 2>/dev/null || echo '(none)')
\`\`\`

## Prior rescue cycles
$(for d in "$run_dir/rescues"/cycle-*; do
    [[ -d "$d" && "$d" != "$cycle_dir" ]] || continue
    echo "- $(basename "$d"): $(test -f "$d/approved.md" && echo 'approved' || echo 'incomplete')"
  done)
EOF
log "wrote inputs.md ($(wc -c < "$cycle_dir/inputs.md") bytes)"

# Build the RELENTLESS-INBOX prompt for the LLM to execute on resume.
# Sentinel + body must follow the relentless_relay.sh case-1 format.
{
  echo "# RELENTLESS-INBOX"
  echo
  echo "Run ID: $run_id"
  echo "Rescue cycle: $next_cycle"
  echo "Trigger reason: $(jq -r '.trigger // "unknown"' "$trigger")"
  echo
  echo "## Your job (perform in order, per references/rescue-mode.md)"
  echo
  echo "1. Read \`$cycle_dir/inputs.md\` (trigger, current manifest, recent events)."
  echo "2. Read \`$run_dir/manifest.json\` to know the last successful checkpoint."
  echo "3. Spawn the **background-agent** (grok-4.5 @medium via the native grok"
  echo "   transport) using its prompt at \`$SKILL_DIR/agents/background-agent.md\`"
  echo "   with the inputs bundle. Write its output to \`$cycle_dir/diagnosis.md\`."
  echo "4. Spawn the **rescue-agent** consortium in parallel:"
  echo "   - Slot 'lead' (gpt-5.6-sol @xhigh via the codex transport)"
  echo "   - Slot 'co-pilot' (opus-4.8 @xhigh via the claude-cli transport)"
  echo "   Each reads \`$SKILL_DIR/agents/rescue-agent.md\` + the diagnosis."
  echo "   Outputs: \`$cycle_dir/lead-proposal.md\` and \`$cycle_dir/copilot-proposal.md\`."
  echo "5. Run the **fusion summarize gate** on the two proposals:"
  echo "   \`$SKILL_DIR/scripts/adversarial_review.sh --gate=summarize"
  echo "    --inputs=$cycle_dir/proposals-bundle.json"
  echo "    --out=$cycle_dir/gate-verdict.json\`"
  echo "   Panel, judge, and fuser seats come from \`$HOME_DIR/fusion.config.json\`"
  echo "   (falling back to the skill's assets default) — do NOT pass --models."
  echo "   Pass criteria: the fused verdict JSON has \`\"verdict\": \"pass\"\`."
  echo "6. On approval, write the unified rescue plan to \`$cycle_dir/approved.md\`"
  echo "   in the format documented in references/rescue-mode.md step 4."
  echo "7. Run the self-improvement pass (step 5 of rescue-mode.md): inspect"
  echo "   recent hook misfires + tool errors; propose edits to SKILL.md,"
  echo "   agents/*.md, scripts/*, or hook scripts that would prevent the"
  echo "   recurrence; adversarial-review them before applying."
  echo "8. Update the run manifest's \`rescue_cycles\` array with the cycle"
  echo "   metadata. Persist."
  echo "9. Resume the run from the last successful checkpoint per the rescue"
  echo "   plan's \"State to restore\" + \"Plan changes\" sections."
  echo
  echo "## Constraints that still apply"
  echo
  echo "- Honor budget caps (40h soft, \$50 hard) — don't let rescue spend more"
  echo "  than the original budget allows."
  echo "- Kill switch at \`$HOME_DIR/KILL\` aborts everything."
  echo "- Never run on main/master."
  echo "- Never force-push."
  echo
  echo "## Open questions for the user (or null)"
  echo "(populate during the diagnosis pass)"
} > "$INBOX"

log "RELENTLESS-INBOX prompt written to $INBOX ($(wc -c < "$INBOX") bytes)"

# Takeover = FRESH session. Feature-detect the grok CLI: if present, dispatch
# the prompt headlessly — on grok 0.2.56 (verified) every new invocation IS a
# fresh session (there is no -s/session-id flag); the prompt goes via
# --prompt-file (never argv: ARG_MAX + ps-visibility). --resume/-r is ONLY for
# the USER re-attaching to the newest session later — never for the takeover
# itself. Without the CLI, fall back to staging + manual banner (the
# relentless_relay.sh flow picks the staged file up).
if command -v grok >/dev/null 2>&1; then
  # Archive the staged file so the relay's manual-inject path can't re-fire
  # the same rescue into a later interactive prompt; dispatch FROM the archive.
  mkdir -p "$LATERAL/archive"
  dispatched="$LATERAL/archive/relentless-dispatched-$(date -u +%Y%m%dT%H%M%SZ).md"
  mv "$INBOX" "$dispatched"
  log "grok CLI detected — dispatching fresh headless session (--prompt-file)"
  ( grok --prompt-file "$dispatched" --output-format json \
      > "$cycle_dir/grok-session.log" 2>&1 </dev/null & )
  echo
  echo "==================================================="
  echo "Rescue cycle $next_cycle dispatched for run $run_id."
  echo "Trigger:  $trigger"
  echo "Inputs:   $cycle_dir/inputs.md"
  echo "Session:  fresh headless Grok session — id in $cycle_dir/grok-session.log; re-attach with: grok -r"
  echo "Log:      $cycle_dir/grok-session.log"
  echo
  echo "To re-attach to the rescue session yourself (optional):"
  echo "  grok -r          # re-attaches to the newest session (id in grok-session.log)"
  echo "(--resume/-r is for YOU re-attaching — the rescue itself is"
  echo " already running in the fresh session above.)"
  echo "==================================================="
  exit 0
fi

echo
echo "==================================================="
echo "Rescue cycle $next_cycle prepared for run $run_id."
echo "Trigger:  $trigger"
echo "Inputs:   $cycle_dir/inputs.md"
echo "Prompt:   $INBOX"
echo
echo "grok CLI not found — manual handoff required."
echo "Paste the contents of $INBOX into the active Grok session,"
echo "or — if running under tmux — the relentless_relay.sh hook will pick"
echo "it up automatically on next /clear + Enter."
echo "==================================================="
exit 0
