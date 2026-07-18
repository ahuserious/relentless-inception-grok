# Setup

End-to-end setup for `relentless-inception` (Grok Build edition). There are exactly three
things to get right:

1. **Install** the skill where Grok Build discovers it (clone recommended).
2. **The fuser seat** — install and sign in the claude CLI, because the default fuser is
   `fable-5 @xhigh` over headless `claude -p`, **not** the Grok session.
3. **At least one deliberation backend** beyond the floor. With nothing else live, gates still
   run on the sanctioned grok-panel floor.

Shipping tools (`uv`, `dagger`, `docker`) are only needed if your plan declares a deliverable —
see `references/prereqs.md` for the full matrix.

---

## 1. Install

The host is **Grok Build** (xAI's coding CLI). Install and authenticate it first:

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok login        # SpaceXAI OAuth at auth.x.ai — SuperGrok or X Premium+ subscription
```

### Clone path (recommended)

```bash
git clone https://github.com/ahuserious/relentless-inception-grok \
  ~/.grok/skills/relentless-inception-grok
```

`SKILL.md` lives at the repo root, so a flat clone into a skills directory loads directly.
Grok Build scans `~/.grok/skills/` natively and also reads `~/.claude/skills/` and
`./.claude/skills/` zero-configuration (toggle: `[compat.claude] skills` in
`~/.grok/config.toml`). Prefer `~/.grok/skills/`: both editions share the frontmatter name
`relentless-inception`, and in Grok Build's user tier `~/.grok/skills/` outranks
`~/.claude/skills/` — so the Grok edition wins inside Grok Build while Claude Code (which
never scans `~/.grok/`) keeps seeing only a Claude-edition install. Qualified names
(`user:relentless-inception`) disambiguate collisions. The entrypoint stays
`/relentless-inception`.

### Plugin path (marketplace — partially unverified)

```
grok plugin install ahuserious/relentless-inception-grok --trust
```

Grok Build's marketplace catalog format is its own **`plugin-index.json`** — not Claude
Code's `marketplace.json`. This repo ships Claude Code's `.claude-plugin/plugin.json` +
`marketplace.json` for Claude Code compatibility; docs.x.ai claims blanket Claude Code
plugin/marketplace compat, but the Grok Build user guide does not confirm those exact
manifests parse — **UNKNOWN**. If `grok plugin install` does not surface the skill on your
build, use the clone path (always works).

### One-shot installer

`install.sh` does the clone, scaffolds `~/.claude/relentless-inception-grok/` from the shipped
defaults (never overwriting an existing config), and runs preflight:

```bash
curl -fsSL https://raw.githubusercontent.com/ahuserious/relentless-inception-grok/main/install.sh | bash
# or, after cloning:
bash ~/.grok/skills/relentless-inception-grok/install.sh
```

---

## 2. The fuser seat (and your Grok session)

**The fuser is the single most important seat** (~18-point quality swing across fusers on a
fixed panel — see `references/adversarial-gates.md`). In the Claude Code edition the fuser
inherited the host session's model. Here the host session is Grok, and the default fuser is
instead **`fable-5 @xhigh` via the `claude-cli` transport** — a fresh headless `claude -p`
call. Strongest-available-model-fuses is the lever, and it is worth one extra CLI:

```bash
npm i -g @anthropic-ai/claude-code
claude auth login     # Claude subscription OAuth — no ANTHROPIC_API_KEY needed
```

Subscription auth carries over to non-bare `claude -p` calls on the same machine. Do **not**
export `ANTHROPIC_API_KEY` in your shell profile: if both are present the key overrides
subscription auth and every claude-cli seat silently switches to API billing. If you want the
`anthropic` direct backend too, put the key in `secrets.env` only (§3).

**Sanctioned fallback — `grok-session`.** If the claude CLI is absent, the fuser falls back to
the Grok Build session model as a fresh instance. Only then do your session settings matter for
fusion quality — keep the session on your strongest model and effort (`/model grok-4.5`,
`--effort xhigh`; effort levels: none/minimal/low/medium/high/xhigh/max). Fuser provenance is
always recorded in the gate verdict, so the tearsheet shows which fuser actually ran.

> **Context budget.** Context is per-model, not a flat number: `grok-4.5` (the default
> session model) has a 500K window, `grok-build-0.1` 256K, and the `grok-4.3` /
> `grok-4.20` family 1M. The 500K default is half the 1M the claude edition routed to, so
> summarize-gate pressure is correspondingly higher — keep the orchestrator session lean
> and follow the tighter compaction cadence in `references/runtime-and-hooks.md`.

The run screenshots in `docs/img/` were captured in the Claude Code edition — same pipeline
and seat labels (`judge:fable-low` + `fuser:fable-xhigh`), different host chrome.

---

## 3. Choose deliberation backends (seven transports)

The gate driver probes a ladder at preflight (`scripts/check_prereqs.sh` writes
`gate_capability.json`) and each gate uses the highest live rung. Configure which transports
are on in `~/.claude/relentless-inception-grok/fusion.config.json` under `backends` (toggle
keys: `grok_native`, `claude_cli`, `codex`, `xai_direct`, `openai_direct`,
`anthropic_direct`, `openrouter`; seat `transport` values: `grok`, `claude-cli`, `codex`,
`xai`, `openai`, `anthropic`, `openrouter`). Seats mix freely across backends.

### Subscription backends (no API key)

#### `grok` — native Grok Build sub-agent seats

Runs a seat as a Grok Build subagent, deferred to the host orchestrator: the gate driver
writes the pre-seat bundle and exits **42**, and the orchestrator spawns the seat — the same
exit-42 pattern the Claude edition used for its `claude` seats. Auth is your `grok login`
subscription; nothing to configure. Grok Build subagents cannot nest (only the top-level
session spawns them), so grok seats always run from the orchestrator itself. This transport
powers the grok-panel floor and the cheap-judge fallback.

#### `claude-cli` — headless `claude -p` seats (new in this edition)

Claude subscription auth (§2). The exact seat invocation the driver uses (verified locally
on claude CLI 2.1.214):

```bash
# timeout-bounded (perl-alarm wrapper — macOS has no `timeout`); prompt on stdin
bounded claude -p \
  --model claude-fable-5 --effort xhigh \
  --allowedTools "Read" --permission-mode dontAsk \
  --output-format json < "$prompt_file" | jq -r '.result'
```

- The prompt goes on **stdin** (argv would cap large bundles; stdin allows up to 10MB).
- `--allowedTools "Read"` + `--permission-mode dontAsk` = read-only review seat. There is
  **no `--max-turns` flag** (verified absent on 2.1.214) — do not pass one.
- Every call is timeout-bounded (per-effort ladder: xhigh/max 1800s, high 600s, else 180s).
- `--output-format json` returns `result`, `session_id`, `total_cost_usd`, `usage`.
- Judge seats run the same shape at `--effort low`; the fuser at `--effort xhigh`.
- Panel seats are stateless: independent parallel calls plus `wait`, no shared session.
- Config model names (`fable-5`, `opus-4.8`) are skill-level names; the driver resolves
  them to `--model` slugs `claude-fable-5` / `claude-opus-4-8` — both verified accepted on
  2.1.214 (the short aliases `fable`/`opus` resolve to the same models).
- Do **not** pass `--bare` (it skips keychain OAuth and then demands `ANTHROPIC_API_KEY`).
- Pin claude CLI 2.1.214+ — the version this invocation was verified on.

#### `codex` — codex CLI (unchanged)

Powers the `gpt-5.6` panel seats through your ChatGPT subscription:

```bash
npm i -g @openai/codex     # need >= 0.144 for the gpt-5.6 family
codex login                # ChatGPT account; no OpenAI API key
```

Codex model aliases this skill resolves: `sol`→`gpt-5.6-sol`, `luna`→`gpt-5.6-luna`,
`terra`→`gpt-5.6-terra`; any catalog slug also works, at **any** reasoning effort
(`minimal`…`xhigh`; `ultra` via raw CLI only). Effort is passed as
`-c model_reasoning_effort=<level>` (there is no `--effort` flag on codex ≥0.144). The Claude
Code codex *plugin* step from the previous edition is gone — under Grok Build the driver calls
the codex CLI directly.

### Provider-direct API backends (key in `secrets.env`)

All four keys live in one file — the only place a key ever goes (never in a config, a script
default, or any repo file). All four lines ship **blank** in the example:

```bash
mkdir -p ~/.claude/relentless-inception-grok
cp ~/.grok/skills/relentless-inception-grok/assets/secrets.env.example \
   ~/.claude/relentless-inception-grok/secrets.env
chmod 600 ~/.claude/relentless-inception-grok/secrets.env
# then fill in only the keys for backends you enable
```

Credentials are checked for **presence only** — the skill never reads, logs, or echoes a key
value.

#### `xai` — api.x.ai (the default panel-expert seat)

- Key line: `XAI_API_KEY=`
- Endpoint: `POST https://api.x.ai/v1/chat/completions` with
  `Authorization: Bearer $XAI_API_KEY` — OpenAI-compatible request/response shape.
- **Verified live (2026-07-18):** `GET https://api.x.ai/v1/models` → 200 with slugs
  `grok-4.5`, `grok-4.3`, `grok-4.20-0309-reasoning`, `grok-4.20-0309-non-reasoning`,
  `grok-4.20-multi-agent-0309`, `grok-build-0.1`; `grok-4.5` accepts
  `reasoning_effort:"xhigh"` (200; `usage.completion_tokens_details.reasoning_tokens`
  present; prompt caching active via `cached_tokens`).
- Prefer over the native `grok` transport when the panel expert must be **pinned** to
  grok-4.5 @xhigh independent of the session — which is exactly the shipped default panel
  seat. Billing is pay-as-you-go, separate from the SuperGrok subscription.

#### `openai` — api.openai.com

- Key line: `OPENAI_API_KEY=`
- Endpoint: `POST https://api.openai.com/v1/chat/completions` with
  `Authorization: Bearer $OPENAI_API_KEY`.
- Models: gpt-5.6 family **only** (`sol` default; `luna`/`terra` valid config values, never
  in defaults).
- Prefer over `codex` when there is no ChatGPT subscription on the box (CI, containers) or
  the `codex login` browser flow is impractical.

#### `anthropic` — api.anthropic.com

- Key line: `ANTHROPIC_API_KEY=`
- Endpoint: `POST https://api.anthropic.com/v1/messages` with `x-api-key: $ANTHROPIC_API_KEY`
  plus an `anthropic-version` header.
- Models: `fable-5` and `opus-4.8` only.
- Prefer over `claude-cli` when the claude CLI is absent (CI, containers). Keep the key in
  `secrets.env` only — exported shell-wide it flips your claude-cli subscription seats to API
  billing (§2).

#### `openrouter` — openrouter.ai (unchanged)

- Key line: `OPENROUTER_API_KEY=`
- Endpoint: `POST https://openrouter.ai/api/v1/chat/completions` with
  `Authorization: Bearer $OPENROUTER_API_KEY`.
- Enables direct panel seats **and** the one-call server-side `openrouter/fusion` fan-out
  rung.
- Prefer when you want cross-vendor model diversity from a single key, or none of the other
  backends are available.

### Floor — grok-panel (nothing to install)

If no other backend is live, gates descend to the floor rung: a fresh-context Grok subagent
panel (N=4, distinct adversarial personas) over the native `grok` transport, stamped
`"degraded": true`. It needs no external backend, so **a gate never silently skips** — it just
records the degradation.

---

## 4. Configure the panel

Copy the shipped default and edit your copy (skill upgrades overwrite the default, never your
copy):

```bash
cp ~/.grok/skills/relentless-inception-grok/assets/fusion.config.default.json \
   ~/.claude/relentless-inception-grok/fusion.config.json
```

The default — one seat from each of three vendors:

```jsonc
{
  "backends": { "grok_native": true, "claude_cli": true, "codex": true,
                "xai_direct": true, "openai_direct": false,
                "anthropic_direct": false, "openrouter": false },
  "panel": [
    { "transport": "xai",        "model": "grok-4.5", "count": 1, "effort": "xhigh" },
    { "transport": "codex",      "model": "sol",      "count": 1, "effort": "xhigh" },
    { "transport": "claude-cli", "model": "fable-5",  "count": 1, "effort": "xhigh" }
  ],
  "judge": { "transport": "claude-cli", "model": "fable-5", "effort": "low" },
  "fuser": { "transport": "claude-cli", "model": "fable-5", "effort": "xhigh",
             "fallback": "grok-session" }
}
```

| Config seat | Transport | Where it runs | Fallback if transport dead |
|-------------|-----------|---------------|----------------------------|
| panel `grok-4.5` @xhigh | `xai` | direct HTTP to api.x.ai (needs `XAI_API_KEY`) | native `grok` seat |
| panel `sol` @xhigh | `codex` | codex CLI via ChatGPT sub | `openai` direct if keyed |
| panel `fable-5` @xhigh | `claude-cli` | headless `claude -p` via Claude sub | `anthropic` direct if keyed |
| `judge` fable-5 @low | `claude-cli` | cheap headless call | cheap `grok` seat |
| `fuser` fable-5 @xhigh | `claude-cli` | headless call, fresh instance | `grok-session` (§2) |

`luna`/`terra` are valid but deliberately out of the default (weaker than `sol`). Raise any
`count` to 2 for heavier gates. Temperature applies only to provider-direct HTTP calls (panel
1.0, judge pinned 0) and is **not** a diversity lever — vary models/personas instead. See
`references/fusion-deliberation.md` for what the panel/judge/fuser actually do and screenshots
of a live gate.

---

## 5. Preflight, then invoke

```bash
bash ~/.grok/skills/relentless-inception-grok/scripts/check_prereqs.sh   # exit 0 = ready
```

```
/relentless-inception <your multi-day build task>
```

The entrypoint runs preflight itself and surfaces a remediation hint for anything missing.
Credentials are checked for **presence only** — the skill never reads, logs, or echoes a key
value.
