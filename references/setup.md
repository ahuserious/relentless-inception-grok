# Setup

End-to-end setup for `relentless-inception`. There are exactly three things to get right:

1. **Install** the skill (plugin or clone).
2. **Your Claude Code session** — the model + effort, because the fuser seat inherits them.
3. **At least one deliberation backend** — the codex plugin (default) **or** OpenRouter. With
   neither, gates still run on the sanctioned claude-panel floor.

Shipping tools (`uv`, `dagger`, `docker`) are only needed if your plan declares a deliverable —
see `references/prereqs.md` for the full matrix.

---

## 1. Install

### Plugin path (managed updates)

```
/plugin marketplace add ahuserious/relentless-inception
/plugin install relentless-inception@ahuserious
```

The repo root is itself the plugin (`.claude-plugin/plugin.json`), and the marketplace entry
points at it (`"source": "."`). Skills are namespaced by plugin, so the entrypoint is
`/relentless-inception:relentless-inception` — or just `/relentless-inception` when
unambiguous.

### Clone path (plain skill directory)

```bash
git clone https://github.com/ahuserious/relentless-inception \
  ~/.claude/skills/relentless-inception
```

`SKILL.md` lives at the repo root, so a flat clone into `~/.claude/skills/<name>` loads
directly. Both install paths come from the same repo.

### One-shot installer

`install.sh` does the clone, scaffolds `~/.claude/relentless-inception/` from the shipped
defaults (never overwriting an existing config), and runs preflight:

```bash
curl -fsSL https://raw.githubusercontent.com/ahuserious/relentless-inception/main/install.sh | bash
# or, after cloning:
bash ~/.claude/skills/relentless-inception/scripts/../install.sh
```

---

## 2. Your Claude Code session (model + effort)

**The fuser is the single most important seat** (~18-point quality swing across fusers on a
fixed panel — see `references/adversarial-gates.md`). The fuser runs as
`claude-code-session`: **whatever model your Claude Code session is currently on**, as a fresh
instance. So set your session to your strongest available model before invoking:

```
/model fable
/effort xhigh
```

This is why the shipped default panel pairs a Fable 5 judge and a Fable 5 (session) fuser, and
why the run screenshots show `judge:fable-low` + `fuser:fable-xhigh`. If your session is on a
weaker model, the fuser degrades with it — so keep the session on the model you want fusing the
gate verdicts.

> Set the session **before** the run. Changing `/model` mid-run changes which model fuses
> subsequent gates.

---

## 3. Choose a deliberation backend

The gate driver probes a ladder at preflight (`scripts/check_prereqs.sh` writes
`gate_capability.json`) and each gate uses the highest live rung. Configure which transports
are on in `~/.claude/relentless-inception/fusion.config.json` under `backends`.

### Backend A — codex plugin (default; ChatGPT subscription, no API key)

Powers the `gpt-5.6` panel seats (`sol`/`luna`/`terra`) through your ChatGPT subscription.

1. Install the Codex CLI and sign in:
   ```bash
   npm i -g @openai/codex     # need >= 0.144 for the gpt-5.6 family
   codex login                # ChatGPT account; no OpenAI API key
   ```
2. Install the **official** codex plugin for Claude Code (unmodified upstream — this skill
   *drives* it, it is not forked or bundled here):
   ```
   /plugin marketplace add openai/codex-plugin-cc
   /plugin install codex@openai-codex
   ```
3. Enable it in config: `"backends": { "codex_plugin": true }`.

Codex model aliases this skill resolves: `sol`→`gpt-5.6-sol`, `luna`→`gpt-5.6-luna`,
`terra`→`gpt-5.6-terra`; any catalog slug also works, at **any** reasoning effort
(`minimal`…`xhigh`; `ultra` via raw CLI only). Effort is passed as
`-c model_reasoning_effort=<level>` (there is no `--effort` flag on codex ≥0.142).

### Backend B — OpenRouter (optional; API key)

Enables direct HTTP panel seats and the one-call server-side `openrouter/fusion` fan-out (Rung
1 of the ladder).

1. Put the key in secrets (only place a key ever goes — never in a config or in `plugin.json`):
   ```bash
   cp ~/.claude/skills/relentless-inception/assets/secrets.env.example \
      ~/.claude/relentless-inception/secrets.env
   chmod 600 ~/.claude/relentless-inception/secrets.env
   # then set OPENROUTER_API_KEY=... on its line
   ```
2. Enable it in config: `"backends": { "openrouter": true }`. Both backends may be on at once;
   seats mix freely.

### Backend fallback — claude-panel floor (nothing to install)

If neither codex nor OpenRouter is live, gates descend to Rung 3: a fresh-context Claude
subagent panel (N=4, distinct adversarial personas), stamped `"degraded": true`. It needs no
external backend, so **a gate never silently skips** — it just records the degradation.

---

## 4. Configure the panel

Copy the shipped default and edit your copy (skill upgrades overwrite the default, never your
copy):

```bash
cp ~/.claude/skills/relentless-inception/assets/fusion.config.default.json \
   ~/.claude/relentless-inception/fusion.config.json
```

The default:

```jsonc
{
  "backends": { "codex_plugin": true, "openrouter": false },
  "panel": [
    { "transport": "claude", "model": "fable-5",  "count": 1, "effort": "xhigh" },
    { "transport": "codex",  "model": "sol",      "count": 1, "effort": "xhigh" },
    { "transport": "claude", "model": "opus-4.8", "count": 1, "effort": "xhigh" }
  ],
  "judge": { "transport": "claude", "model": "fable-5", "effort": "low" },
  "fuser": { "transport": "claude-code-session", "effort": "xhigh" }
}
```

| Config seat | Transport | Where it runs | Shows in the run UI as |
|-------------|-----------|---------------|------------------------|
| panel `fable-5` | `claude` | subagent in your session (no key) | `panel:*` (Panel phase) |
| panel `sol` @xhigh | `codex` | codex CLI / plugin via ChatGPT sub | `panel:*` (Panel phase) |
| panel `opus-4.8` @xhigh | `claude` | subagent in your session (no key) | `panel:*` (Panel phase) |
| `judge` fable-5 @low | `claude` | cheap subagent | `judge:fable-low` (Fuse phase) |
| `fuser` @xhigh | `claude-code-session` | your session model, fresh instance | `fuser:fable-xhigh` (Fuse phase) |

`luna`/`terra` are valid but deliberately out of the default (weaker than `sol`). Raise any
`count` to 2 for heavier gates. Temperature applies only to openrouter-direct calls (panel 1.0,
judge pinned 0) and is **not** a diversity lever — vary models/personas instead. See
`references/fusion-deliberation.md` for what the panel/judge/fuser actually do and screenshots
of a live gate.

---

## 5. Preflight, then invoke

```bash
bash ~/.claude/skills/relentless-inception/scripts/check_prereqs.sh   # exit 0 = ready
```

```
/relentless-inception <your multi-day build task>
```

The entrypoint runs preflight itself and surfaces a remediation hint for anything missing.
Credentials are checked for **presence only** — the skill never reads, logs, or echoes a key
value.
