# Runtime, tearsheets, hooks, and honest scope

## Proof tearsheets

Every cycle of every run produces an HTML tearsheet at
`~/.claude/relentless-inception-grok/runs/<run_id>/cycle-<N>/tearsheet.html`. The tearsheet
shows:

- The plan + acceptance criteria
- Per-phase unit table with pass/fail/retry counts
- Per-subagent reasoning traces (collapsed by default, click to expand)
- Tool-call log (filtered by significance)
- Test harness output (pytest, dagger functions, simulated-user persona reports)
- Adversarial-review verdicts at all three gates
- HTML+screen-recording embeds when `--exec=skynet` recorded them
- A short LLM-as-judge meta-summary at the top

Generator: `scripts/tearsheet.py`. Template: `assets/tearsheet_template.html`. The HTML is
self-contained — no external requests — so a tearsheet attached to an email or shared on a
USB still renders.

## Hooks installed by this skill

`scripts/install_hooks.sh` writes this skill's hook entries into **`~/.claude/settings.json`
only**. Grok Build honors Claude-format hooks from that file by default (`[compat.claude]
hooks` in `~/.grok/config.toml` toggles the scan), so one Claude-format install serves both
hosts. The installer deliberately does **not** write `~/.grok/hooks/` — with the
Claude-compat scan active, a second native copy there would make the same hook fire twice.
The settings fragment looks like:

```json
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "scripts/stall_watchdog.sh", "timeout": 10}]}]}}
```

**Three** hook entries are wired:

- **`UserPromptSubmit`** → `scripts/relentless_relay.sh`. Watches for `# RELENTLESS-INBOX`
  prompts; when seen, clears the active session and re-pastes the body. Foundation for
  rescue. (On Grok Build, rescue session takeover itself dispatches a **fresh** headless
  session — `grok -p "$(cat inbox)" -s "$(uuidgen)"`, or the same over ACP `grok agent
  stdio` — not tmux keystrokes; `--resume`/`-r` is only for the *user* re-attaching to
  that new session afterwards. The claude-edition tmux relay script is retained only
  behind `RELAY_EXPERIMENTAL=1`. See `rescue-mode.md`.)
- **`Stop`** → `scripts/stall_watchdog.sh`. Records every Stop event with a timestamp; the
  background-agent reads this trail to detect stalls.
- **`statusLine`** → `scripts/status_line.sh`. **Inert under Grok Build** — there is no
  `statusLine` hook event (the closest UI knob is the terminal-title
  `[ui.notifications] "title.items"` config) — but it becomes active if the same install
  is reused under Claude Code, where it renders run-id / current phase / retries / last
  gate verdict. Under Grok Build those live in the run's `manifest.json` instead.

Hook contract (Grok Build): commands receive stdin JSON (`hookEventName`, `sessionId`,
`cwd`, `workspaceRoot`, plus tool fields on tool events) and env `GROK_HOOK_EVENT` /
`GROK_SESSION_ID` / `GROK_WORKSPACE_ROOT`; default timeout is 5 s (ours are set
explicitly); hook failures and timeouts fail-open.

Run `bash scripts/install_hooks.sh` once before the first invocation. The script is safe to
re-run and refuses to overwrite hooks it doesn't recognize.

### Compat appendix — coexisting with the Claude Code edition

Both editions install their hooks into `~/.claude/settings.json`. If the Claude Code
edition of this skill already wired its own `UserPromptSubmit` / `Stop` / `statusLine`
entries there (pointing at its copy of the scripts), Grok Build will fire those too — keep
only one edition's entries so a single event doesn't run two relays/watchdogs. And never
mirror this edition's entries into `~/.grok/hooks/`: Grok Build already fires the
`~/.claude/settings.json` copies, so a native duplicate double-fires.

## Workflow at a glance

```
              ┌──────── ENTRY (user invokes /relentless-inception ARGS) ─────────┐
              │                                                                   │
              ▼                                                                   ▲
       1. capture-intent ──→ 2. planner + architecture-analyzer pair               │ rescue
              │                       │                                           │ relay
              ▼                       ▼                                           │ resurrects
       PLAN GATE (adversarial) ─ fail → revise plan ←─┐                            │ from
              │                                       │                            │ here
              ▼ pass                                  │                            │
       3. dev-worker pool (parallel) ──→ per-unit verify ─ fail (≤3 retries)       │
              │                                                                   │
              ▼ all pass                                                           │
       PHASE GATE (adversarial) ─ fail → retry phase ←─┐                           │
              │                                        │                           │
              ▼ pass                                   │                           │
       4. test-harness-designer + simulated users ──→ tearsheet draft              │
              │                                                                   │
              ▼                                                                   │
       SUMMARIZE GATE (3-model parallel)                                           │
              │                                                                   │
              ▼ all 3 pass                                                         │
       5. ship (uv / workspaces / dagger)                                          │
              │                                                                   │
              ▼                                                                   │
       6. final tearsheet + done                                                   │
              │                                                                   │
              ▲────────── stall? failure burst? hook misfire? ──────── rescue ─────┘
```

## How this skill relates to neuro-harness

The user's `neuro-harness` monorepo at `/Users/DanBot/neuro-harness/` is where the runtime
lives:

- `packages/orchestrator/src/orchestrator/` holds the Python dataclasses (`Role`,
  `ModelBinding`, `Plan`, `Phase`, `Unit`, `RunManifest`) — scripts in this skill import
  them when running inside that workspace, and fall back to stdlib-only shims when they
  don't.
- `vendor/claude-temporal-plugin/`, `vendor/mcp-context-forge/`, `vendor/gitnexus/`,
  `vendor/uv-mcp/`, `vendor/mcp2cli/`, `vendor/mcp-server-tree-sitter/`,
  `vendor/tree-sitter-pine/`, `vendor/pinelsp/` are the MCP and tooling layer the skill
  assumes.
- `docker-compose.yaml` brings up the stack (Temporal + ContextForge + Postgres + Redis +
  3 bridged stdio MCPs + the dev app); this skill's runs typically execute inside
  `neuro-harness-app`.

When this skill runs outside the `neuro-harness` workspace it still functions, but
adversarial-review + nexus-graph features that depend on git-nexus/context7 MCPs are
gracefully reduced.

## Honest scope (what's runtime vs what's contract)

The skill is **a designed contract + state-management harness**, not a standalone
autonomous daemon. The LLM that loads this skill IS the orchestrator. Scripts are the
supporting machinery:

- **What scripts do:** scaffold run directories, write/read state, validate JSON gate
  outputs, claim rescue triggers, run seat invocations with timeouts (codex CLI, headless
  `claude -p`, provider-direct HTTP), dispatch the fresh headless rescue session (the tmux
  relay is `RELAY_EXPERIMENTAL=1`-gated), generate tearsheets, ship via uv/Dagger.
- **What the LLM does:** read SKILL.md + the relevant references on entry, spawn subagents
  (Grok Build's native `spawn_subagent` seats) per the role prompts in `agents/`, call
  `scripts/adversarial_review.sh` at gates, write/read manifest + checkpoint state, invoke
  `scripts/rescue.sh` when a trigger fires, follow the documented workflow.

Safety claims (budget caps, kill switch, no force-push) are honored by the LLM following
the documented contract. The kill switch (`~/.claude/relentless-inception-grok/KILL`) IS
additionally checked by every shell script at invocation, so a triggered kill propagates
through state-changing commands within seconds.

A future iteration may add a launchd / cron daemon that periodically runs
`stall_watchdog.sh --sweep` + `rescue.sh` so stall detection + rescue handoff happen
without the LLM needing to remember — see the claude edition's
`evals/codex-review-2026-05-19.md` (not imported into this edition) for the patch backlog.

## Iterate forward, not in place

The skill is intentionally young. When you encounter a real problem — a gate that's too
forgiving, a rescue cycle that drifts, an agent role that lacks a tool it needs — open a new
run with `/skill-creator` against this skill to revise. Don't hand-edit the SKILL.md
mid-run; use the iteration loop. The whole point is to keep getting better.

The initial adversarial review by codex is preserved in the claude edition's
`evals/codex-review-2026-05-19.md` (the `evals/` directory was not imported into this
edition) along with per-finding patch status — start from there if you're picking up
Slice-2 work.
