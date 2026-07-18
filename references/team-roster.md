# Team roster

This skill spawns a typed cast of subagents. Defaults come from `agents/` files; the
user's spec in the parent monorepo's `docs/SPEC-original.md` is the source of truth for
any role tuning. Each seat names its transport: `grok` = native Grok Build sub-agent seat
(full host tool surface, worktree isolation), `codex` = codex CLI via ChatGPT
subscription, `claude-cli` = headless `claude -p` via Claude subscription. Context is
per-model — grok-4.5 (the default session model) 500K, grok-build-0.1 256K, the grok-4.3 /
grok-4.20 family 1M; the 500K default is half the claude edition's 1M routing, so plan
compaction cadence accordingly.

| Role                       | Default model | Transport  | Default effort   | When fired                                                       |
|----------------------------|---------------|------------|------------------|------------------------------------------------------------------|
| `planner`                  | opus-4.8      | claude-cli | xhigh            | every plan-mode entry; pairs with architecture-analyzer          |
| `architecture-analyzer`    | gpt-5.6-sol   | codex      | xhigh            | inverse-engineers similar codebases via git-nexus                |
| `dev-worker`               | grok-4.5      | grok       | high             | per-unit build inside worktrees                                  |
| `adversarial-review`       | gpt-5.6-sol   | codex      | high (xhigh rescue) | every plan + phase + summarization gate                          |
| `nexus-graph-writer`       | opus-4.8      | claude-cli | high             | writes graph artifacts inline as work proceeds                   |
| `nexus-graph-synthesizer`  | gpt-5.6-sol   | codex      | xhigh            | folds parallel graph writes into a coherent view                 |
| `uv-dagger-deploy`         | grok-4.5      | grok       | high             | builds + ships via Dagger pipelines                              |
| `uv-package`               | grok-4.5      | grok       | high             | turns workspace members into installable wheels                  |
| `uv-workspaces`            | grok-4.5      | grok       | high             | workspace-level fixes (members, sources, lockfile)               |
| `test-harness-designer`    | gpt-5.6-sol   | codex      | xhigh            | designs simulated-user personas + scenarios + assertions         |
| `temporal-tester`          | opus-4.8      | claude-cli | high             | drives Temporal workflows + Temporal-gated integration tests     |
| `test-evaluator`           | opus-4.8      | claude-cli | xhigh            | reads outputs, decides pass/fail against acceptance criteria      |
| `background-agent`         | grok-4.5      | grok       | medium           | watches for stalls, drives the rescue path                       |
| `rescue-agent`             | gpt-5.6-sol   | codex      | xhigh            | fresh context, reads full session log, repairs the harness       |

Host-native execution roles (`dev-worker`, the `uv-*` shippers, `background-agent`) ride
native grok seats — they need the host's full tool surface and worktree integration.
Review/design-class roles deliberately sit on non-Grok vendors (gpt-5.6-sol via codex,
opus-4.8/fable-5 via claude-cli) for cross-vendor independence at the gates. Other
verified xAI slugs (e.g., `grok-4.3`, `grok-4.20-0309-reasoning`) are valid config values
for grok seats; grok-4.5 is the default.

Read `agents/<role>.md` for the prompt template each role uses. Each file is
self-contained so the orchestrator can dispatch without re-deriving instructions.
`agents/<role>.md` files are loaded per-spawn; the orchestrator doesn't read them all up
front.
