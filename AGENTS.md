# relentless-inception (Grok Build edition)

This repository is a **skill for Grok Build** (xAI's `grok` CLI): a long-running
autonomous orchestrator that plans, builds, adversarially reviews, ships, and rescues
multi-day coding runs. Its signature mechanism is the **fusion deliberation gate** —
every plan/phase/summarize checkpoint is reviewed by a multi-model panel (grok-4.5 +
gpt-5.6-sol + fable-5 by default), then synthesized by a judge + fuser into a
provenance-stamped verdict. Fail-closed; a sanctioned native grok-panel floor means the
gate always runs.

## Where things live

- **`SKILL.md`** (repo root) — the skill router. Read it first; it points to the
  normative reference for every subsystem (`references/*.md`).
- **`references/setup.md`** — full setup walkthrough: install, transports, config,
  preflight. Start here to get running.
- **`scripts/`** — gate driver, preflight, hooks, rescue, shipping ladders.
- **`agents/`** — per-role prompt templates loaded per-spawn.
- User config + secrets: `~/.claude/relentless-inception-grok/` (separate namespace from
  the Claude Code edition, so both coexist).

## Entrypoint

Invoke as **`/relentless-inception <multi-day build task>`** (the skill's frontmatter
name is `relentless-inception`; this repo is the Grok Build edition of it, v0.3.0-grok).

Use it only for multi-hour/multi-day work whose "done" is a functional proof (real
install, simulated-user run, HTML tearsheet) and that must survive its own failures
unattended. Not for single-file edits, quick refactors, or work you want to babysit.

## Safety rails (non-negotiable)

Never runs on `main`/`master`; no force-push ever; budget caps per run/cycle; kill
switch at `~/.claude/relentless-inception-grok/KILL`; `rm -rf` confined to the run's
own namespace. Credentials are presence-checked only — never echoed.
