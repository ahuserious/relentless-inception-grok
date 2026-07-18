# Prerequisites

The skill expects the following tools and credentials. The entrypoint runs `scripts/check_prereqs.sh` first and refuses to start if anything's missing, surfacing the remediation hint.

---

## Tools

| Tool        | Why                                                     | Install                                       |
|-------------|---------------------------------------------------------|-----------------------------------------------|
| grok        | This is a Grok Build skill — the host CLI                | `curl -fsSL https://x.ai/cli/install.sh \| bash` |
| claude      | optional but recommended — `claude-cli` transport (default fable-5 panel seat, judge, fuser) | `npm i -g @anthropic-ai/claude-code` |
| codex       | adversarial-review + rescue model routing               | `npm i -g @openai/codex` (>= 0.144), then `codex login` |
| uv          | shipping, member install                                 | `curl -LsSf https://astral.sh/uv/install.sh \| sh`  |
| dagger      | Una + Dagger shipping ladder                             | `curl -fsSL https://dl.dagger.io/dagger/install.sh \| sh` |
| docker      | live containerized testing                               | Docker Desktop or compatible engine            |
| tmux        | optional — legacy keystroke relay (`relentless_relay.sh`) only; Grok Build rescue prefers headless dispatch (`grok --prompt-file …`) / ACP (`grok agent stdio`), which need no tmux | `brew install tmux` |
| jq          | ship-report parsing, gate JSON plumbing                  | `brew install jq`                              |
| git         | obvious                                                  | usually preinstalled                           |

## Credentials

Subscription logins and API keys both count as credentials here — each row enables its
transport, and any missing seat degrades down the gate ladder, never silently.

| Credential            | Required? | Used for                                                        |
|-----------------------|-----------|-----------------------------------------------------------------|
| `grok login` (SuperGrok / X Premium+) | required | the host itself — orchestrator session, native `grok` seats, grok-panel floor, `grok-session` fuser fallback |
| `claude auth login` (Claude subscription) | optional, recommended | the `claude-cli` transport — default fable-5 panel seat, judge, and fuser via headless `claude -p`; no API key involved |
| `codex login` (ChatGPT subscription) | optional  | the `codex` transport — gpt-5.6-sol panel seat |
| XAI_API_KEY           | optional  | the `xai` direct backend — the default grok-4.5 @xhigh panel-expert seat (pay-as-you-go, separate from the SuperGrok subscription) |
| OPENAI_API_KEY        | optional  | the `openai` direct backend — gpt-5.6 seats without a ChatGPT subscription (CI, containers) |
| ANTHROPIC_API_KEY     | optional  | the `anthropic` direct backend — fable-5/opus-4.8 seats without the claude CLI. Keep it in `secrets.env` only: exported shell-wide it overrides subscription auth and flips claude-cli seats to API billing |
| OPENROUTER_API_KEY    | optional  | the `openrouter` backend — direct panel seats + the one-call `openrouter/fusion` rung |
| GITHUB_TOKEN          | optional  | PR creation, GitHub Actions kickoff                             |
| TEMPORAL_API_KEY      | optional  | only for `--exec=skynet` with Temporal Cloud                    |
| HF_TOKEN              | optional  | Hugging Face MCP access                                         |

The shipped default panel uses `grok login` (host) + `XAI_API_KEY` + `codex login` +
`claude auth login` — see `references/setup.md` for the backend-by-backend walkthrough.

All four provider keys (`XAI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
`OPENROUTER_API_KEY`) belong in `~/.claude/relentless-inception-grok/secrets.env` (chmod 600;
all four lines ship blank in `assets/secrets.env.example`) — never in a config file, a script
default, or an exported shell profile. The skill never reads, logs, or echoes a credential
value — only its presence.

---

## MCPs

These MCP servers are expected to be reachable. The skill works with reduced functionality when one is missing, but features depending on a missing MCP are skipped.

Grok Build has first-class MCP support: register servers with `grok mcp <list|add|remove|doctor>` (or a project `.mcp.json`, which needs folder trust — the same gate as project hooks), inspect with `/mcps` in the TUI, and per docs.x.ai existing Claude Code MCP configuration is auto-read (`[compat.claude]` toggles in `~/.grok/config.toml`). All five below are standard MCP servers, so they load under any of those routes:

| MCP             | Required for                                             | Reduced-mode if missing                       | Under Grok Build |
|-----------------|----------------------------------------------------------|------------------------------------------------|------------------|
| git-nexus       | architecture-analyzer's inverse-engineering pass        | analyzer runs without cross-repo symbol search | supported — `grok mcp add` or Claude Code compat |
| context7        | planner's current-docs lookups                          | planner uses its training-data knowledge only  | supported — `grok mcp add` or Claude Code compat |
| mcp2cli         | kitchen-sink-monorepo's CLI-ref generation              | mode unavailable                                | supported — `grok mcp add` or Claude Code compat |
| infranodus      | Obsidian/graph visualization                             | tearsheet has no graph view                     | supported — `grok mcp add` or Claude Code compat |
| serena          | symbolic code search inside the orchestrator             | falls back to grep/Read                         | supported — `grok mcp add` or Claude Code compat |

Federating them through ContextForge still works — point `grok mcp add` at the gateway instead of each server.

---

## External skills the orchestrator may invoke

Grok Build reads skills from `~/.grok/skills/`, `~/.claude/skills/`, and `./.claude/skills/` zero-configuration, so already-installed skills resolve as-is:

- codex-side gate evaluation and rescue routing now go through the codex CLI directly (the Claude Code `codex:*` plugin skills are not assumed present under Grok Build)
- `docs-dual-lookup` — used when an agent role needs library docs
- `parallel-web` / `perplexity-search` / `research-lookup` — used by architecture-analyzer for upstream comparisons
- `deep-tool-wiki` — used when the orchestrator hits a HyperFrequency-forked tool it doesn't know

None of these are strictly required, but their absence reduces the quality of the relevant step.

---

## Run check

Before kicking off a run:

```bash
bash ~/.grok/skills/relentless-inception-grok/scripts/check_prereqs.sh
```

Exit code 0 = ready. Non-zero = print remediation hints and refuse. The orchestrator entrypoint runs this automatically.
