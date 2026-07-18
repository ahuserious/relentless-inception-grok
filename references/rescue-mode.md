# Rescue mode

Rescue is what makes this skill survive its own failures. It's not a fallback — it's a designed escape hatch that fires automatically when the orchestrator gets stuck.

The premise: the orchestrator can get stuck in ways the orchestrator can't see, because it's the one stuck. Recovery requires *fresh context* and *fresh attention* from a different model. Rescue provides both.

---

## Triggers (any one fires rescue)

1. **N consecutive failures on the same unit** (default N=3). Per-unit retry budget exhausted with no progress.
2. **Unattended stall**: `STALL_MINUTES` (default 12) of no agent output AND no tool calls. Watched by the background-agent via the Stop hook trail.
3. **Dead process**: a background subprocess spawned by this skill exits non-zero without writing a status report.
4. **Hook misfire**: a hook installed by this skill (three entries in `~/.claude/settings.json`: `relentless_relay.sh`, `stall_watchdog.sh`, `status_line.sh`) returns non-zero on three consecutive invocations. The `statusLine` entry is inert under Grok Build (no such event), so in practice only the first two can misfire there.
5. **Adversarial-review escalation**: any of the three gates fails its max-iteration budget (3 retries).
6. **Manual**: the user types `# RELENTLESS-RESCUE` into the chat, which the relay hook intercepts and converts into a rescue trigger.

---

## What rescue does (the 7 steps)

### 1. Background-agent reads the situation

`background-agent` (default `grok-4.5 @medium` via the native `grok` transport — a fresh
context, though the same vendor as the orchestrator; the cross-vendor fresh attention
comes from the consortium in step 2) gets passed:

- The full session log so far
- The tool-call trace
- The current run manifest
- The last successful checkpoint marker
- The trigger reason (which of the six above fired)

Its job is *diagnosis only* — surface *what* is stuck and *why*. It doesn't propose a fix; that's the consortium's job.

Output: `~/.claude/relentless-inception-grok/runs/<run_id>/rescues/<cycle>/diagnosis.md`

### 2. Consortium proposes a fix

Two fresh contexts spawn in parallel, both on non-Grok transports so the fix comes from
outside the stuck orchestrator's model:

| Slot     | Model        | Effort | Transport    |
|----------|--------------|--------|--------------|
| Lead     | gpt-5.6-sol  | xhigh  | `codex`      |
| Co-pilot | opus-4.8     | xhigh  | `claude-cli` |

If neither non-Grok transport is live, the consortium falls back to two fresh
`grok-session` sub-agents with disjoint context bundles — stamped `degraded` /
single-provider, exactly like the rung-3 gate floor.

Each reads the diagnosis + a curated subset of the session log (just enough to be informed, not enough to inherit the stuck thinking). They independently propose:

- What state to restore the orchestrator to
- What changes to make to plan/manifest before re-entering
- Whether any skill / hook / agent definition needs editing

Output: `~/.claude/relentless-inception-grok/runs/<run_id>/rescues/<cycle>/{lead,copilot}-proposal.md`

### 3. Triple-gate review of the proposals

Both proposals run through the standard summarize-gate (3 reviewers in parallel). The gate produces:

- A unified rescue plan (lead + copilot, reconciled, with reviewer notes incorporated)
- Or a `regenerate` verdict, in which case the consortium gets the reviewers' notes and tries again

Max 3 attempts to produce an approved rescue plan. If still failing after 3, the run pauses for human intervention.

### 4. Approved plan → markdown summary

The approved rescue plan is written to:

```
~/.claude/relentless-inception-grok/runs/<run_id>/rescues/<cycle>/approved.md
```

Format (rigid — the relay step depends on it):

```markdown
# RELENTLESS-INBOX

Run ID: <run_id>
Resumes from: <last-good-checkpoint>
Reason for rescue: <trigger>
Cycle: <N>

## What to do next
<numbered list of next actions, each one a complete instruction>

## Constraints that still apply
<list of things that must NOT change>

## Open questions for the user (or null)
<if any — these are surfaced at next user interaction>

## Self-improvement edits applied
<list of edits to skill/hook/agent files, with sha and rationale>
```

### 5. Self-improvement pass

Before clearing context, the background-agent inspects:

- Recent **hook misfires** — should the hook be patched? Renamed? Removed?
- Recent **tool-call errors** — does a guard need adding to a script? Is a deferred tool not being loaded?
- Recent **drift moments** — was the orchestrator following an outdated note in `SKILL.md`? Should an `agents/<role>.md` be more explicit?

Any proposed edits get adversarial-reviewed before applying. Applied edits are listed in the rescue summary's "Self-improvement edits applied" section so the user can audit them.

### 6. Clear context via the relay (Grok Build edition)

The claude edition drove a tmux `/clear` + paste sequence against Claude Code's TUI. Grok
Build exposes a *documented* fresh-session surface, so the default relay no longer depends
on keystroke injection.

**Default path — headless re-dispatch (reliable, documented):**

1. Save `approved.md` to `~/.claude/relentless-inception-grok/lateral-pass/pending-relentless.md`.
2. Start a **fresh-context** Grok session seeded with the rescue plan as its first prompt —
   a genuinely new context window, new session id, no TUI automation:

   ```
   grok -p "$(cat pending-relentless.md)" -s "$(uuidgen)" --output-format json
   ```

   (or drive the same over ACP with `grok agent stdio` when an IDE/harness is attached).
   Capture the returned `sessionId`; the run continues in that session and is watchable via
   `grok sessions list` / `grok dashboard`. `--resume`/`-r <id>` is only for the **user**
   re-attaching interactively to that new session — the takeover itself is always the
   fresh `-s "$(uuidgen)"` dispatch above, never a resume of the stuck session.
3. Move the pending file to `archive/`.

The result is identical in spirit to the claude edition: a fresh-context orchestrator whose
first user prompt is the rescue plan — obtained here through Grok's headless-session surface
instead of keystrokes.

**Fallback path — tmux keystroke relay (EXPERIMENTAL, gated):** `scripts/relentless_relay.sh`
still ships the old tmux `/clear` + paste sequence for driving a *live interactive* TUI, but
no primary source confirms Grok Build's TUI is reliably drivable by tmux keystrokes, and the
exact in-TUI clear command is **UNKNOWN** (Grok documents `/resume`, `/fork`, and Esc-Esc
`/rewind`, but not a `/clear`). It is therefore gated behind `RELAY_EXPERIMENTAL=1`. When
that env var is unset, the script does not attempt keystroke injection — it writes the inbox
file, prints its path, and defers to the headless re-dispatch above (or surfaces the plan for
the user to paste into a fresh session themselves).

### 7. Continue from checkpoint

The fresh orchestrator reads the rescue plan, picks up the run manifest, spawns subagents from the last good checkpoint, and proceeds. The previous rescue cycle is logged in the manifest under `rescue_cycles`; the next phase's adversarial-review reads it as additional context.

---

## What rescue does NOT do

- **Does not retry the same approach.** If the lead+copilot consortium proposes "just retry," the gate rejects it. Rescue must change *something* about the approach.
- **Does not modify production code without the gate.** All self-improvement edits go through adversarial-review.
- **Does not run forever.** Three failed rescue cycles in a row pauses the run for human intervention.
- **Does not bypass the kill switch.** `~/.claude/relentless-inception-grok/KILL` still wins.

---

## Implementation

`scripts/rescue.sh` is the entrypoint. It orchestrates steps 1-7 above. Each step writes intermediate artifacts so the rescue itself is recoverable.

`scripts/stall_watchdog.sh` is the trigger detector — it runs as the Stop hook and as a periodic check. When it detects a stall, it writes a trigger file at `~/.claude/relentless-inception-grok/triggers/rescue-<run_id>-<timestamp>.json` which the orchestrator polls.

`scripts/relentless_relay.sh` handles context clearing. Its default path is the headless
re-dispatch of step 6 (no interactive-session automation); the legacy tmux keystroke relay
against a live TUI remains behind `RELAY_EXPERIMENTAL=1` and is unverified on Grok Build's
TUI. Every other component runs from background processes.

---

## Designing your run to be rescue-friendly

Two practices reduce the chance of needing rescue, and make it cheaper when it happens:

1. **Write checkpoints often.** After every phase, the orchestrator writes a checkpoint to the manifest. Make phases small enough that losing one phase's worth of work is acceptable.
2. **Keep dev-worker prompts self-contained.** When a dev-worker prompt requires "context from earlier in the conversation," it can't be re-run cleanly after rescue. Bake the context into the prompt.

These are also good practices for non-rescue runs.

---

## Trigger 7 — provider-capacity kill (v0.2; the one that actually happens)

**Signal:** an in-flight dev-worker or gate seat dies with a usage-limit / quota /
credit-exhaustion error (session-window cap, 402, 429-hard), or the harness reports the
subagent terminated on a provider error. This was the ONLY rescue trigger observed in
nc-harness-20260704 (7 occurrences) and v0.1 didn't list it.

**Fast path (checkpoint → probe → verbatim redispatch)** — no consortium:

1. Record the kill in `rescues/` (which units, what was staged, provider + error class).
2. Snapshot: commit staged work on the run branch with an explicit pathspec (never `git add -A`).
3. Clock check: if the provider publishes a reset time, arm a resume trigger for it;
   otherwise probe on a backoff ladder (15m → 1h → 4h) with a zero-cost "PROBE-OK" agent.
4. On probe success: redispatch each killed unit VERBATIM (same prompt + a resume-notes
   preamble pointing at its staged work). Do not replan; do not shrink scope silently.
5. Stamp the run manifest `environment_adaptations` with the kill + resume timeline.

Only escalate to the full rescue consortium if the same unit dies twice AFTER a
successful probe (that's a real stall, not capacity).
