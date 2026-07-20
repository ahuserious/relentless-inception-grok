# Relentless Inception for Grok Build

Relentless Inception is a runtime-backed Grok Build plugin for bounded multi-agent deliberation, generative fusion, exact-artifact adversarial review, and verified execution handoff. It combines the strongest parts of the original Relentless Inception workflow, Batch Create Eval, Gigaprompt, Exaflop, and evidence-first benchmark practice without relying on prompt compliance for budgets, provider dispatch, receipts, or release gates.

Version `0.4.1` targets Grok Build `0.2.106` or newer.

## What is real

- A bundled dependency-free Python MCP runtime dispatches provider seats, validates configuration, enforces budgets and timeouts, records invocation-bound receipts, preserves minority findings, and fails closed.
- Native Grok Build agents remain host-managed subagents with Grok tools, permissions, worktrees, and visible task state.
- External provider seats receive only the bounded packet sent to the MCP tool. They cannot inspect or change the local workspace.
- Hooks provide turn-end guidance only. Grok hooks fail open on hook errors, so the MCP runtime is the hard enforcement boundary.
- There is no hidden settings panel. `/relentless-config` exposes the complete schema and validated configuration tools inside Grok Build.

## Frontier-only defaults

The shipped maximum-intelligence profile has no automatic quality downgrade.

| Surface | Default model | Purpose |
|---|---|---|
| Grok Build host and native agents | `grok-4.5` at `high` effort | workspace reasoning, implementation, native adversarial review |
| Direct xAI API seats | `grok-4.5` | independent panel, judge, synthesis, and exact-hash gates |
| Optional Codex seat/handoff | `gpt-5.6-sol` | cross-family review or execution when Codex is explicitly configured |

OpenAI direct, Anthropic direct, OpenRouter, OpenRouter Fusion, and TrustedRouter-compatible endpoints remain fully configurable. They are disabled until the operator supplies credentials and enables their seats. Older Grok models, cheaper judges, and weaker fallbacks are never selected by the shipped profile.

With only xAI credentials, the proven live topology is Grok 4.5 role-diverse fusion plus a Grok 4.5 native host. Enabling a Codex seat adds GPT-5.6 Sol cross-model diversity. This project does not describe multiple calls to one model as cross-model fusion.

## Install

Validate and install a local checkout:

```bash
grok plugin validate /absolute/path/to/relentless-inception-grok
grok plugin install /absolute/path/to/relentless-inception-grok --trust
grok plugin list --json
grok plugin details relentless-inception-grok
grok inspect --json
grok mcp doctor relentless-inception
```

Remote installs should pin a full Git commit SHA:

```bash
grok plugin install ahuserious/relentless-inception-grok@FULL_COMMIT_SHA --trust
```

Trust is required because the plugin launches its local MCP process. Inspect the pinned source before trusting it. The repository currently has no selected distribution license; choose one before publishing a public release.

The earlier flat-skill edition installed under `~/.grok/skills/relentless-inception-grok`. Move that checkout outside Grok's scanned skill roots before enabling this plugin, otherwise two skills can claim the same `relentless-inception` name. Nothing in the new installer reads or deletes the legacy checkout.

## Use

Inside Grok Build:

```text
/relentless-inception <difficult build or decision>
/relentless-config show
/relentless-config doctor
/relentless-review <artifact or completed-work claim>
```

The normal lifecycle is:

1. Grok maps the goal, acceptance criteria, scope, and smallest sufficient evidence packet.
2. Independent seats answer before seeing one another.
3. A structured judge identifies consensus, contradictions, blind spots, and lone-minority findings.
4. The strongest configured synthesizer writes a fresh result instead of voting or splicing.
5. Independent reviewers gate the exact artifact SHA-256.
6. Native Grok agents implement only after plan and pre-execution gates pass.
7. Post-execution, final, and summarize gates review the actual diff, tests, provenance, cost ledger, and remaining risk.

Every native agent bundled here explicitly selects exact `grok-4.5` at `high`, the strongest effort exposed by Grok Build 0.2.106. Host-side subagent discovery reports plugin agents under namespaced IDs such as `relentless-inception-grok:adversarial-review`. The 0.2.106 top-level `grok --agent` launcher does not resolve that discovered namespace consistently, so headless validation should pass the installed profile file explicitly. Direct xAI seats also use exact `grok-4.5`, not an alias. Grok Build `-s/--session-id` applies to interactive sessions in current releases and is ignored in headless mode; use `--prompt-file` for a fresh headless dispatch and `--resume` only when continuation is intended.

A bounded native-agent smoke can be run without invoking the external fusion panel:

```bash
RI_GROK_PLUGIN_PATH="$(grok plugin list --json | jq -r \
  '.[] | select(.name == "relentless-inception-grok") | .path')"
grok --agent "$RI_GROK_PLUGIN_PATH/agents/adversarial-review.md" \
  --model grok-4.5 --reasoning-effort high --max-turns 1 \
  --no-subagents --disable-web-search --no-plan --tools '' --verbatim \
  --single "Do not call tools. Review this exact artifact and return the required JSON."
```

## Configuration and credentials

Configuration is deep-merged from the shipped `config/default.json` and a private user override. `RELENTLESS_INCEPTION_CONFIG` and `RELENTLESS_INCEPTION_DATA_DIR` can select explicit paths; the default data root is `~/.grok/relentless-inception`.

The runtime stores only credential environment-variable names such as:

- `XAI_API_KEY`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `OPENROUTER_API_KEY`
- `TRUSTED_ROUTER_API_KEY`

Never put plaintext keys in JSON, agent Markdown, hooks, repository files, or Grok's plugin manifest. The runtime can optionally read an explicitly configured owner-only (`0600`) static environment file; it never invokes a shell and never returns the values through configuration or doctor tools. Native Grok agents use the host's existing login. The plugin does not read or copy `~/.grok/auth.json`.

OpenRouter is implemented and tested with mocks, but was not called in the local release campaign because no working OpenRouter credential was available. Direct xAI Grok 4.5 was exercised live.

## Verification

Offline:

```bash
python3 -m unittest discover -s tests -v
python3 -m compileall -q runtime tests
grok plugin validate .
```

Installed:

```bash
grok plugin list --json
grok inspect --json
grok mcp doctor relentless-inception --json
```

Live provider and benchmark tests are opt-in and billable. A packaging validator proves discovery, not provider behavior; retained ledgers and task-harness receipts are the live evidence.

## Repository map

```text
plugin.json                    Grok Build plugin manifest
.mcp.json                      bundled stdio MCP server
skills/                        user workflows and settings surface
commands/                      slash-command compatibility entrypoint
agents/                        native Grok 4.5 subagent definitions
hooks/hooks.json               defense-in-depth turn-end guidance
runtime/                       enforced provider/fusion/gate runtime
config/default.json            complete shipped settings
schemas/                       configuration and structured-output schemas
examples/                      provider/router opt-in fragments
tests/                         dependency-free negative and contract tests
docs/                          architecture, configuration, security, validation
```

Legacy `assets/`, `references/`, and `scripts/` are retained temporarily for provenance. They are not the v0.4 execution path and must not be installed as hooks or used for provider dispatch.

## Design lineage

- Relentless Inception: phased execution, checkpoints, rescue, and explicit handoff.
- Batch Create Eval: independent work units, exact acceptance criteria, and realistic shakedowns.
- Gigaprompt: evidence-backed completion, context checkpoints, and stable-artifact review.
- Exaflop: deliberately different expert perspectives with hard time and cost limits.
- TrustedRouter/OpenRouter fusion research: generative synthesis over voting, cheap structured comparison, strongest available fuser, and preservation of lone-correct minority evidence.

See [architecture](docs/ARCHITECTURE.md), [configuration](docs/CONFIGURATION.md), [security](docs/SECURITY.md), and [validation](docs/VALIDATION.md).
