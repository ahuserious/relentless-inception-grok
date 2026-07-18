# Settings and flags

This file documents every knob the skill exposes. Most users will never touch these — the defaults are tuned for "I won't be watching" runs.

---

## Model + effort defaults (per role)

These are the defaults applied when no flag overrides them. Model names are concrete
slugs; the Transport column resolves provider routing (`grok` = native Grok Build
sub-agent seat, `codex` = codex CLI via ChatGPT subscription, `claude-cli` = headless
`claude -p` via Claude subscription). **Context reality note:** context is per-model —
grok-4.5 (the default session model) has a 500K window, grok-build-0.1 256K, and the
grok-4.3 / grok-4.20 family 1M. The 500K default is half the 1M the claude edition routed
to, so summarize-gate pressure is higher — compact earlier and keep bulky artifacts on
disk, not in the orchestrator window.

| Role                      | Model              | Transport   | Effort      | Notes                                       |
|---------------------------|--------------------|-------------|-------------|---------------------------------------------|
| planner                   | opus-4.8           | claude-cli  | xhigh       | always xhigh, no degradation                |
| architecture-analyzer     | gpt-5.6-sol        | codex       | xhigh       |                                             |
| orchestrator              | grok-4.5           | (host session) | xhigh    | the Grok Build session itself; never below xhigh |
| dev-worker                | grok-4.5           | grok        | xhigh       | overridable to high for cost                |
| adversarial-review        | gpt-5.6-sol        | codex       | high        | xhigh in rescue mode                        |
| nexus-graph-writer        | opus-4.8           | claude-cli  | high        | one-per-graph-write                         |
| nexus-graph-synthesizer   | gpt-5.6-sol        | codex       | xhigh       | one-per-merge-batch                         |
| uv-dagger-deploy          | grok-4.5           | grok        | high        |                                             |
| uv-package                | grok-4.5           | grok        | high        |                                             |
| uv-workspaces             | grok-4.5           | grok        | high        |                                             |
| test-harness-designer     | gpt-5.6-sol        | codex       | xhigh       | always xhigh                                |
| temporal-tester           | opus-4.8           | claude-cli  | high        |                                             |
| test-evaluator            | opus-4.8           | claude-cli  | xhigh       | always xhigh                                |
| background-agent          | grok-4.5           | grok        | medium      | watchdog mode, doesn't write code           |
| rescue-agent              | gpt-5.6-sol        | codex       | xhigh       | forced xhigh; no degradation                |

## Fallback policy

When the router can't satisfy a request:

1. Retry once with a 30-second backoff.
2. If still failing, try the named fallback (e.g., gpt-5.6-sol via codex → gpt-5.6-sol via `openai` direct if `OPENAI_API_KEY` is set; opus-4.8 via claude-cli → fable-5 via claude-cli; grok-4.5 via `xai` direct → a native grok seat).
3. If the fallback fails, **pause the run** with a clear error. **Never silently degrade to a smaller model.**

The exception: `--allow-degradation` flag turns step 3 into "drop one effort level and continue." Use deliberately; surfaced as a warning at every gate.

---

## Entrypoint flags

```
/relentless-inception "<task>" \
  --plan=staff-up|kitchen-sink-monorepo|lawyer-up \
  --exec=gigaprompt|proof-loops|skynet|exaflop-infiniloop \
  --intensity=1|2|3 \
  --orchestrator-review-style=code-function-nexus|adversarial-review|simulate-users-harness \
  --subagent-review-style=verify-proof|adversarial-pass-fail \
  --budget-soft-hours=N \
  --budget-hard-usd=N \
  --allow-degradation \
  --resume=<run_id>
```

Defaults:

- `--plan=staff-up`
- `--exec=proof-loops`
- `--intensity=3`
- `--orchestrator-review-style=adversarial-review`
- `--subagent-review-style=verify-proof`
- `--budget-soft-hours=40`
- `--budget-hard-usd=50`
- `--allow-degradation` off

## Budget caps

| Cap                    | Default | What happens when hit                              |
|------------------------|---------|----------------------------------------------------|
| `--budget-soft-hours`  | 40 h    | Run pauses for user review                          |
| `--budget-hard-usd`    | $50     | Run pauses; no further router calls until raised    |
| Per-unit retries       | 3       | Escalate to rescue                                  |
| Per-gate iterations    | 3       | Escalate to rescue                                  |
| Per-run rescue cycles  | 3       | Pause for human intervention                        |

The kill switch — `~/.claude/relentless-inception-grok/KILL` — bypasses none of these; it's an *additional* stop.

---

## Environment

Provider keys live in `~/.claude/relentless-inception-grok/secrets.env` (chmod 600). They
are presence-checked only — values are never printed. Each key is required **only** if a
seat uses the matching provider-direct HTTP transport:

- `XAI_API_KEY` — `xai` direct seats (api.x.ai; the default panel's grok-4.5 expert seat)
- `OPENAI_API_KEY` — `openai` direct seats
- `ANTHROPIC_API_KEY` — `anthropic` direct seats
- `OPENROUTER_API_KEY` — **optional**; only for `openrouter` seats (e.g., a Gemini seat routed via the `openrouter` transport)

The subscription transports need no key in secrets.env: `grok` native seats use Grok
Build's own login (`~/.grok/auth.json`), `codex` uses the ChatGPT subscription, and
`claude-cli` uses the Claude subscription OAuth on this machine.

Other env vars the skill reads:

- `CODEX_HOME` — defaults to `~/.codex`
- `RELENTLESS_INCEPTION_HOME` — defaults to `~/.claude/relentless-inception-grok`; the runs/rescues/logs root
- `STALL_MINUTES` — default 12; watchdog threshold

---

## Run state directories

```
~/.claude/relentless-inception-grok/
├── runs/
│   └── <run_id>/
│       ├── plan.md
│       ├── manifest.json
│       ├── cycle-<N>/
│       │   ├── tearsheet.html
│       │   ├── tool-calls.jsonl
│       │   ├── reasoning-traces/
│       │   ├── adversarial-verdicts/
│       │   └── ship-report.json
│       └── rescues/
│           └── <cycle>/
│               ├── diagnosis.md
│               ├── {lead,copilot}-proposal.md
│               └── approved.md
├── lateral-pass/
│   ├── pending-relentless.md
│   └── archive/
├── triggers/
│   └── rescue-<run_id>-<timestamp>.json
└── KILL                       <-- create this to stop all running orchestrators
```
