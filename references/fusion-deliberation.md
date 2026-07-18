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
  re-verifier · minority-finding advocate). Default panel: 1× `fable-5` + 1× `gpt-5.6-sol`
  @xhigh + 1× `opus-4.8` @xhigh.
- **Judge** — one *cheap* model. Emits compact JSON only (`consensus`, `contradictions`,
  `blind_spots`, `verdict_tally`, …) — **never a verdict**. The judge barely moves quality, so
  cheap is always safe (default `fable-5` @low).
- **Fuser** — one *strongest available* model, a fresh instance that must differ from the judge
  and from the artifact's author. Writes a **generative synthesis**, not a vote or an average —
  it must **preserve lone-correct minority findings** (the single panelist who caught the real
  flaw is exactly what averaging destroys). Runs as `claude-code-session`, so set your session
  to your strongest model (`/model fable`, `/effort xhigh`) before the run.

Design empirics (TrustedRouter DRACO artifact, `ahuserious/trustedrouter-fusion-artifact`): the
**fuser is the lever** (~18-pt swing), the **judge barely matters**, voting/averaging are
banned, and **temperature does not decorrelate errors** — diversity comes from distinct
models/personas.

## What a live gate looks like

Invoking a gate with the session on Fable 5 (note `Fable 5` in the status line, the run id
`nc-harness-p1b-...`, and the `prd-gap-fusion-plan` gate about to fire):

![Invoking a fusion gate with the session on Fable 5](../docs/img/fusion-invoke-fable.png)

The gate running — Map ✓ and Panel ✓ complete, Fuse in progress. The Fuse phase shows the two
synthesis seats: `judge:fable-low` (Fable 5, done — 45.6k tokens, 37s) and `fuser:fable-xhigh`
(Fable 5 session model, just starting):

![A fusion gate mid-run: Map and Panel done, Fuse in progress](../docs/img/fusion-panel-fuse.png)

Reading the panels:

- **Header** — `prd-gap-fusion-plan · PRD-vs-built gap scan with sol/fable/opus fusion
  deliberation · 6/7 agents · 10m26s`. `sol/fable/opus` is the default panel; `6/7 agents` is
  the deliberation's seat count in flight.
- **Phases** — `Map 2/2 ✓`, `Panel 3/3 ✓` (the three panelists), `Fuse 1/2` (judge done, fuser
  running). This is the Map → Panel → Fuse pipeline above, live.
- **Fuse seats** — `judge:fable-low` is the cheap structuring pass; `fuser:fable-xhigh` is the
  session-model synthesis that emits the schema-validated verdict. `fable-xhigh` is exactly the
  `/model fable` + `/effort xhigh` session propagating into the fuser seat.

## Where each seat is configured

Panel / judge / fuser composition lives in `~/.claude/relentless-inception/fusion.config.json`
(shipped default: `assets/fusion.config.default.json`). The full seat → transport → UI-label
mapping is in `references/setup.md#4-configure-the-panel`. The structured output of every
seat/judge/fuser call validates against `assets/verdict.schema.json` before aggregation, and
every call is stamped with full provenance (`panel`, `judge_model`, `fuser_model`,
`inputs_sha256`, ladder position, degradation flags) into the run's `ledger.jsonl`.

## Why it earns its place

On the neuro-centrifuge P1b run, a phase gate's codex panel (`sol`/`luna`/`terra`) caught two
donor-library determinism bugs — HashMap-ordered Pareto selection and minibatch padding — that
both the implementing dev-worker and the orchestrator's own green test run had missed. A single
reviewer, or a voting scheme that drowns a lone-correct finding, would not have surfaced them.
That is the whole argument for fusion over a single gate reviewer.
