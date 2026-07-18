---
name: relentless-inception
version: 0.3.0-grok
description: Grok Build edition. Long-running autonomous orchestrator that consolidates /goal, /batch-create-eval, /exaflop, and /gigaprompt into a single team of planning, executor, and review subagents. Use this skill when the user asks for "relentless inception", "ship this end-to-end and don't stop until it works", "/relentless-inception", "stand up a full harness for X", "build until the proof tearsheet is green", or describes a multi-day project that needs the orchestrator + adversarial gates + rescue-mode + HTML proof tearsheets. Also trigger for live containerized testing, uv/Una/Dagger shipping, simulated-user harnesses, or any pipeline where "done" requires functional proof rather than just code compiling. Triple-gated adversarial review on planning, phase, and summarization; rescue mode resurrects stalled runs with a fresh-context consortium. The nuclear option for long autonomous work — does NOT fire casually. NOT for single-file edits, refactors, PR review, research questions, or anything you want to babysit turn-by-turn.
---

# /relentless-inception

**This is the Grok Build edition** — the host is xAI's Grok Build CLI (`grok`), and the
orchestrator/session model is Grok. Same pipeline and entrypoint as the Claude Code
edition; transports, prerequisites, and context notes below are Grok-specific.

The "I'm walking away from the laptop and it needs to actually finish" orchestrator.

This skill replaces four ancestors — `/goal`, `/batch-create-eval`, `/exaflop`,
`/gigaprompt` — with a single team-of-agents harness that plans, builds, reviews, ships,
and resurrects itself when stuck. This SKILL.md is a **router**: it tells you what exists
and points to the reference file for each part. Read the references named below; don't
work from this overview alone for a real run.

The companion Python types live at `packages/orchestrator/src/orchestrator/` in the user's
`neuro-harness` monorepo (Role, ModelBinding, Plan, Phase, Unit, RunManifest); scripts
import from there inside that workspace and fall back to stdlib-only shims elsewhere.

## When to use (and not)

Use when **all three** are true:

1. The work is **multi-hour to multi-day** and would be painful to babysit turn-by-turn.
2. "Done" means a **functional proof** — a real install, a real simulated-user run, an
   HTML tearsheet — not just a green build.
3. The user wants the harness to **survive its own failures** — stalls, hook misfires,
   tool errors, context blowouts — without giving up.

If any are false, prefer a smaller tool. Do NOT use for:

- Single-file edits, refactors that fit in one coding pass, or interactive teaching.
- Work where the user wants to review every step — this skill runs unattended.
- Anything where a stall or wrong decision would damage production. The blast radius
  assumes safe local + branch environments; tear down + retry must be free.

For "look at this PR" use `/review`; for "sketch a plan" use plain conversation (this skill
is *execution*); for one test use the test-harness skill directly.

## The team

A typed cast of subagents (`planner`, `architecture-analyzer`, `dev-worker`,
`adversarial-review`, nexus graph writers/synthesizers, uv/dagger shippers, test designers
+ evaluators, `background-agent`, `rescue-agent`). Full role table with default
model/effort and firing conditions: **`references/team-roster.md`**. Per-role prompt
templates: **`agents/<role>.md`** (loaded per-spawn).

## Modes

Flags on the entrypoint. Planning and execution modes compose orthogonally. Default is
`staff-up` planning + `proof-loops` execution.

- **Planning (`--plan=…`)**: `staff-up` *(default)*, `kitchen-sink-monorepo`, `lawyer-up`.
  Details + when to pick each: **`references/planning-modes.md`**.
- **Execution (`--exec=…`)**: `gigaprompt`, `proof-loops` *(default)*, `skynet`,
  `exaflop-infiniloop`. Details: **`references/execution-modes.md`**.

## The triple gate

The single most important pattern — if it doesn't fire, the orchestrator drifts. An
adversarial review runs at three checkpoints:

1. **Plan gate** — after planner + architecture-analyzer propose a plan, before any
   dev-worker dispatches.
2. **Phase gate** — after each phase merges, before the next begins.
3. **Summarize gate** — every compaction/handoff (and every rescue-resume preamble) runs the
   same fusion deliberation (N=3 panelists → cheap judge → strong fuser, effort medium);
   fail-closed — the summary regenerates unless the fused verdict passes. Load-bearing
   protection against context-rot drift. **Grok Build context note:** the context window is
   per-model — 500K on grok-4.5 (the default session model), 256K on grok-build-0.1, 1M on
   the grok-4.3 / grok-4.20 family. On the 500K default (vs the 1M routing the Claude
   edition was written against), summarize-gate pressure is materially higher — expect this
   gate to fire more often, keep compaction cadence tight, and keep summaries lean.

Implementation (`scripts/adversarial_review.sh` shelling to `codex`) and pass/fail shape:
**`references/adversarial-gates.md`**.

## Rescue mode

Fires automatically (the background-agent watches via the Stop hook + a periodic stall
check) on: N consecutive failures on one unit (N=3), unattended stall (no output/tool calls
for `STALL_MINUTES`, default 12), a dead spawned subprocess, or a hook misfiring three times
in a row. It reads the full session log, spawns a fresh-context 2-model consortium
(lead gpt-5.6-sol via `codex` + co-pilot opus-4.8 via `claude-cli`, both xhigh),
triple-gates their fix, then restarts from the last checkpoint by dispatching a **fresh**
headless session (`grok --prompt-file <inbox>` — on 0.2.56 every new invocation IS a fresh session (no `-s` flag exists); `--resume`/`-r` is only for
the user re-attaching to that new session afterwards; the legacy tmux keystroke relay
targeted Claude Code's TUI and is kept only behind `RELAY_EXPERIMENTAL=1`). Each cycle
also runs a self-improvement pass.
Full mechanics: **`references/rescue-mode.md`**.

## Settings + flags

Defaults are tuned for "I won't be watching" runs; override per-invocation with explicit
flags. All seats route through frontier models at xhigh with a **no-silent-degradation**
fallback chain (the run pauses on transport error rather than using weaker reasoning; the
context window is per-model — 500K on the default grok-4.5 session model — see the
summarize-gate note above). Full table (model/effort
defaults, budget caps, retry limits, forced-effort conditions):
**`references/settings-and-flags.md`**.

## Proof tearsheets, hooks, runtime

Every cycle emits a self-contained HTML tearsheet at
`~/.claude/relentless-inception-grok/runs/<run_id>/cycle-<N>/tearsheet.html`. The skill also
installs three hook entries (`UserPromptSubmit`, `Stop`, `statusLine`) into
`~/.claude/settings.json` via `scripts/install_hooks.sh` — Grok Build honors Claude-format
hooks from that file; the `statusLine` entry is inert under Grok Build (no such event) but
becomes active if the same install is reused under Claude Code — and has a
documented runtime relationship to the `neuro-harness` monorepo. Tearsheet contents, hook
details, the end-to-end workflow diagram, the contract-vs-daemon honest-scope note, and the
iterate-forward policy all live in: **`references/runtime-and-hooks.md`**.

## Shipping

When the plan declares a deliverable, the harness ships it via three ladders: uv package
(`scripts/shipping/uv_package.sh`), uv workspaces monorepo
(`scripts/shipping/uv_workspaces.sh`), and Una + Dagger
(`scripts/shipping/dagger_deploy.sh`). Each is idempotent and emits a `ship-report.json`
consumed by the tearsheet. Full descriptions: **`references/shipping.md`**.

## Prerequisites

The entrypoint runs `scripts/check_prereqs.sh` first. Seven seat transports exist in this
edition: `grok` (native Grok Build sub-agent seats — always available, no key),
`claude-cli` (headless `claude -p` via your Claude subscription), `codex` (codex CLI via
your ChatGPT subscription), and four provider-direct HTTP transports — `xai`, `openai`,
`anthropic`, `openrouter` — each needing its key (`XAI_API_KEY` / `OPENAI_API_KEY` /
`ANTHROPIC_API_KEY` / `OPENROUTER_API_KEY`) in
`~/.claude/relentless-inception-grok/secrets.env`. The default panel wants `XAI_API_KEY`
plus the `codex` and `claude` CLIs; with none of those available, gates fall to the
sanctioned grok-panel floor (native sub-agent seats) and still run. Shipping needs `uv` +
`dagger`; the `git-nexus` / `context7` / `mcp2cli` / `infranodus` MCPs are used when
present and degrade gracefully when absent. Setup walkthrough: **`references/setup.md`**.
Full matrix: **`references/prereqs.md`**.

## Safety + budgets

- **Never run on `main`/`master`** — the entrypoint refuses unless on a feature branch.
- **Per-run agent-hour budget**: 40h soft cap, then pause for review.
- **Per-cycle cost cap**: $50 USD (router estimate), configurable.
- **Hard cap**: any non-empty file at `~/.claude/relentless-inception-grok/KILL` stops all
  orchestrators within 60s.
- **No force-push, ever.** No flag bypasses this. The harness creates and merges only.
- **No `rm -rf` outside the run's namespace** (`.worktrees/relentless-<run_id>/` and
  `~/.claude/relentless-inception-grok/runs/<run_id>/`).

`exaflop-infiniloop` overrides "stop when convergence is reached" but **respects the budget
caps and kill switch**. There is no flag to bypass the cost cap.

## Trigger guide

Reliably triggers: "relentless inception X" / "/relentless-inception X"; "ship X end-to-end
and don't stop until it's green"; "build a full harness for X" + "I'm going afk"; "run until
the tearsheet is green"; "nuclear option for X"; "full proof-loops / skynet mode / exaflop
X"; "I want simulated-user testing to drive this"; "stand up a uv-workspaces + Dagger
monorepo for X"; "self-healing harness on X"; long task descriptions naming multiple
deliverables across days.

Does NOT trigger: "write a test for X", "look at this PR" (`/review`), "refactor X",
"sketch a plan for X".

## Reading order for a first real run

1. `references/planning-modes.md` — pick the mode matching the task shape.
2. `references/execution-modes.md` — pick the execution mode (default `proof-loops`).
3. `references/adversarial-gates.md` — what passes/fails the gates.
4. `references/rescue-mode.md` — when and how rescue fires.
5. `references/settings-and-flags.md` — confirm model + effort defaults match the plan.
6. `references/shipping.md` — only if the plan declares a deliverable.
7. `references/prereqs.md` — only if a prereq check failed.
8. `references/team-roster.md` + `references/runtime-and-hooks.md` — roster, tearsheets,
   hooks, workflow diagram, honest scope.

## v0.2 — fusion deliberation gates (2026-07-17)

The plan/phase/summarize gates are no longer a single codex reviewer. Each gate runs a
**fusion deliberation** (N independent panelists → cheap judge → strong fuser) over a
probed provider ladder: **openrouter-fusion → codex panel (sol|luna|terra = gpt-5.6
family, ANY effort level; works with the `codex@openai-codex` Claude plugin) →
fresh-context claude-panel (sanctioned degraded floor — the gate always runs)**.
Verdicts validate against `assets/verdict.schema.json`; fail→pass flips require an
independent amendment (never orchestrator-authored); every call lands in the run's
`ledger.jsonl`. Rescue gained trigger 7 (provider-capacity kill → checkpoint/probe/
verbatim-redispatch fast path). Read **`references/adversarial-gates.md`** (the normative
gate spec) and **`references/fusion-deliberation.md`** (the mental model + live-run
screenshots); `scripts/check_prereqs.sh` writes the `gate_capability.json` the
driver uses to pick its rung. Grounding: the TrustedRouter fusion artifact
(`ahuserious/trustedrouter-fusion-artifact`) — fuser is the lever, judge stays cheap,
minority findings must survive synthesis.

## v0.3.0-grok — Grok Build edition (2026-07-18)

Same gate machinery, new host: xAI's Grok Build CLI. This section supersedes the v0.2
provider ladder above. Seat transports are now **seven**:

- **`grok`** — native Grok Build sub-agent seats, deferred to the host orchestrator (the
  exit-42 pattern the Claude edition used for claude seats now applies to grok seats).
  Exit codes from `scripts/adversarial_review.sh`: **42** = the runnable seats
  (codex / provider-direct / claude-cli) plus the judge are done — the host runs the
  deferred grok seats + the fuser from `$OUT.prefusion.json`; **43** = descend to the
  rung-3 grok-panel floor — the host runs the whole floor protocol from
  `$OUT.grok-panel.json`.
- **`claude-cli`** — *new*: headless `claude -p` seats via your Claude subscription.
- **`codex`** — codex CLI via your ChatGPT subscription (unchanged).
- **`xai` / `openai` / `anthropic` / `openrouter`** — provider-direct HTTP; each needs its
  key (`XAI_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `OPENROUTER_API_KEY`) in
  `~/.claude/relentless-inception-grok/secrets.env` (presence-checked, never echoed).

Default panel is three-vendor: **grok-4.5 @xhigh via `xai`** (verified live 2026-07-18:
`api.x.ai/v1/chat/completions` is OpenAI-compatible and grok-4.5 accepts
`reasoning_effort:"xhigh"`, returning reasoning tokens with prompt caching active) +
**gpt-5.6-sol @xhigh via `codex`** + **fable-5 @xhigh via `claude-cli`**. Judge: fable-5
@low via `claude-cli`, falling back to a cheap grok seat when the claude CLI is absent.
Fuser: fable-5 @xhigh via `claude-cli` — strongest-available is the lever (~18-pt swing);
sanctioned fallback `grok-session` (the Grok Build session model) when the claude CLI is
absent. Fuser provenance is always recorded. The sanctioned degraded floor is now the
**grok-panel** (native sub-agent seats), so gates still always run with zero keys and zero
extra CLIs.
