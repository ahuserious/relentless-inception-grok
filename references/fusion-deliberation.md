# Multi-model fusion deliberation

The signature feature of this skill. Every plan / phase / summarize gate is not a single
reviewer but a **fusion deliberation**: several independent panelists review the artifact, a
cheap judge structures their reviews, and a strong fuser writes the final verdict. The
normative, rule-by-rule spec is `references/adversarial-gates.md`; this file is the mental
model plus what a live gate actually looks like.

## The pipeline

```
   gather                 review                        synthesize
 ┌────────┐   bundle   ┌───────────────┐   reviews   ┌─────────┐   ┌──────────────┐
 │  Map   │ ─────────▶ │     Panel     │ ──────────▶ │  Judge  │──▶│    Fuser     │──▶ verdict
 │ (ctx)  │            │ N panelists,  │             │ (cheap, │   │ (strongest,  │
 └────────┘            │ diverse models│             │  JSON)  │   │ ≠ judge,     │
                       └───────────────┘             └─────────┘   │ ≠ author)    │
                                                                   └──────────────┘
```

- **Map** — assemble the review bundle (the artifact under review + its disjoint context
  bundles). Diversity of *context*, not just of models, is what decorrelates panel errors.
- **Panel** — N independent panelists, each a *complete standalone review* from a distinct
  model and adversarial persona (fact-drop hunter · constraint auditor · mechanical
  re-verifier · minority-finding advocate). Default panel (3 vendors): 1× `grok-4.5` @xhigh
  via the `xai` direct transport (the panel-expert seat) + 1× `gpt-5.6-sol` @xhigh via
  `codex` + 1× `fable-5` @xhigh via `claude-cli`.
- **Judge** — one *cheap* model. Emits compact JSON only (`consensus`, `contradictions`,
  `blind_spots`, `verdict_tally`, …) — **never a verdict**. The judge barely moves quality, so
  cheap is always safe (default `fable-5` @low via `claude-cli`; fallback a cheap `grok` seat
  if the Claude CLI is absent).
- **Fuser** — one *strongest available* model, a fresh instance that must differ from the judge
  and from the artifact's author. Writes a **generative synthesis**, not a vote or an average —
  it must **preserve lone-correct minority findings** (the single panelist who caught the real
  flaw is exactly what averaging destroys). Default = `fable-5` @xhigh via `claude-cli` (the
  strongest available model is the lever — ~18-pt swing); sanctioned fallback = `grok-session`
  (the Grok Build session model) when the Claude CLI is absent. Fuser provenance is always
  recorded in the ledger.

Design empirics (TrustedRouter DRACO artifact, `ahuserious/trustedrouter-fusion-artifact`): the
**fuser is the lever** (~18-pt swing), the **judge barely matters**, voting/averaging are
banned, and **temperature does not decorrelate errors** — diversity comes from distinct
models/personas.

## What a live gate looks like

> **These two screenshots were captured in the Claude Code edition** of this skill, where the
> session/fuser ran as the Claude Code session model (Fable 5). The Grok Build edition runs the
> **identical** Map → Panel → Fuse pipeline; only the orchestrator (Grok) and the seat
> transports differ — the grok-edition default panel is `grok-4.5` (xai) + `gpt-5.6-sol`
> (codex) + `fable-5` (claude-cli), with the fuser default `fable-5` @xhigh via `claude-cli`
> (fallback `grok-session`). Read the captures as a faithful picture of the same machinery.

Invoking a gate with the session on Fable 5 (note `Fable 5` in the status line, the run id
`nc-harness-p1b-...`, and the `prd-gap-fusion-plan` gate about to fire) — Claude Code edition:

![Invoking a fusion gate with the session on Fable 5 (Claude Code edition capture)](../docs/img/fusion-invoke-fable.png)

The gate running — Map ✓ and Panel ✓ complete, Fuse in progress. The Fuse phase shows the two
synthesis seats: `judge:fable-low` (Fable 5, done — 45.6k tokens, 37s) and `fuser:fable-xhigh`
(the Claude Code session model, just starting):

![A fusion gate mid-run: Map and Panel done, Fuse in progress (Claude Code edition capture)](../docs/img/fusion-panel-fuse.png)

Reading the panels (the seat names below are the Claude-edition capture; the grok-edition
transport mapping is in the table further down):

- **Header** — `prd-gap-fusion-plan · PRD-vs-built gap scan with sol/fable/opus fusion
  deliberation · 6/7 agents · 10m26s`. `sol/fable/opus` is the default panel; `6/7 agents` is
  the deliberation's seat count in flight.
- **Phases** — `Map 2/2 ✓`, `Panel 3/3 ✓` (the three panelists), `Fuse 1/2` (judge done, fuser
  running). This is the Map → Panel → Fuse pipeline above, live.
- **Fuse seats** — `judge:fable-low` is the cheap structuring pass; `fuser:fable-xhigh` is the
  session-model synthesis that emits the schema-validated verdict. `fable-xhigh` is exactly the
  `/model fable` + `/effort xhigh` session propagating into the fuser seat.

## Where each seat is configured

Panel / judge / fuser composition lives in
`~/.claude/relentless-inception-grok/fusion.config.json` (shipped default:
`assets/fusion.config.default.json`), with all four provider keys in
`~/.claude/relentless-inception-grok/secrets.env` (chmod 600). The full seat → transport →
UI-label mapping is in `references/setup.md#4-configure-the-panel`.

Seat → transport map (Grok Build edition — seven transports). `adversarial_review.sh` drives
every transport except `grok` itself; `grok`-transport seats defer to the host orchestrator
via the exit-42 handoff:

| Transport | Where it runs | Default role | Example model | Credential (presence-only) |
|-----------|---------------|--------------|---------------|----------------------------|
| `xai` | script → `api.x.ai` direct HTTP (OpenAI-compatible; `reasoning_effort:"xhigh"` verified) | **panel expert** | `grok-4.5` @xhigh | `XAI_API_KEY` |
| `codex` | script → codex CLI (ChatGPT subscription) | panel | `gpt-5.6-sol` @xhigh | codex login |
| `claude-cli` | script → headless `claude -p` (Claude subscription) | panel · judge · **fuser** | `fable-5` @xhigh | Claude login / `ANTHROPIC_API_KEY` |
| `openai` | script → `api.openai.com` direct HTTP | optional panel | `gpt-5.6-*` | `OPENAI_API_KEY` |
| `anthropic` | script → `api.anthropic.com` direct HTTP | optional panel | `fable-5` / `opus-4.8` | `ANTHROPIC_API_KEY` |
| `openrouter` | script → `openrouter.ai` direct HTTP | rung-1 fusion | `openrouter/fusion` | `OPENROUTER_API_KEY` |
| `grok` | **host orchestrator** via exit-42 (native sub-agents) | rung-3 floor · fuser fallback (`grok-session`) | `grok-4.5` / session | none (native seats) |

Model rules (hard): OpenAI/GPT seats = gpt-5.6 family only; Anthropic = fable-5 / opus-4.8
only (no `-latest` aliases for new content); xAI panel-expert slug = `grok-4.5` (other
verified slugs are valid config values). The structured output of every seat/judge/fuser call
validates against `assets/verdict.schema.json` before aggregation, and every call is stamped
with full provenance (`panel` incl. per-seat `transport`, `judge_model`, `fuser_model`,
`inputs_sha256`, ladder position, degradation flags) into the run's `ledger.jsonl`.

## Why it earns its place

On the neuro-centrifuge P1b run, a phase gate's codex panel (`sol`/`luna`/`terra`) caught two
donor-library determinism bugs — HashMap-ordered Pareto selection and minibatch padding — that
both the implementing dev-worker and the orchestrator's own green test run had missed. A single
reviewer, or a voting scheme that drowns a lone-correct finding, would not have surfaced them.
That is the whole argument for fusion over a single gate reviewer.
