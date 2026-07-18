#!/usr/bin/env bash
#
# relentless-inception — one-shot installer (flat-clone path).
#
# This installs the skill directory into ~/.claude/skills and scaffolds the
# user config. It is idempotent: existing config is never overwritten.
#
# Prefer the plugin path if you want /plugin-managed updates:
#     /plugin marketplace add ahuserious/relentless-inception
#     /plugin install relentless-inception@ahuserious
#
# Overridable env vars: RI_SKILL_DIR, RI_CONFIG_DIR, RI_REPO
set -euo pipefail

SKILL_DIR="${RI_SKILL_DIR:-$HOME/.claude/skills/relentless-inception}"
CONFIG_DIR="${RI_CONFIG_DIR:-$HOME/.claude/relentless-inception}"
REPO="${RI_REPO:-https://github.com/ahuserious/relentless-inception}"

echo "==> Installing skill -> $SKILL_DIR"
if [ -d "$SKILL_DIR/.git" ]; then
  echo "    existing clone found; fast-forwarding"
  git -C "$SKILL_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$SKILL_DIR")"
  git clone "$REPO" "$SKILL_DIR"
fi

echo "==> Scaffolding user config -> $CONFIG_DIR (existing files left untouched)"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/fusion.config.json" ]; then
  cp "$SKILL_DIR/assets/fusion.config.default.json" "$CONFIG_DIR/fusion.config.json"
  echo "    wrote fusion.config.json"
else
  echo "    fusion.config.json exists; kept"
fi
if [ ! -f "$CONFIG_DIR/secrets.env" ]; then
  cp "$SKILL_DIR/assets/secrets.env.example" "$CONFIG_DIR/secrets.env"
  chmod 600 "$CONFIG_DIR/secrets.env"
  echo "    wrote secrets.env (chmod 600) — only needed for the openrouter backend"
else
  echo "    secrets.env exists; kept"
fi

echo "==> Preflight (tool checks + live model-seat probes); non-fatal"
if ! bash "$SKILL_DIR/scripts/check_prereqs.sh"; then
  echo "!! Preflight flagged issues above. The skill is still installed; resolve them before a real run."
fi

cat <<'EOF'

Done. To finish setup:
  1. Set your Claude Code session so the fuser seat is Fable 5 at xhigh:
         /model fable
         /effort xhigh
     (The fuser = whatever model your session is on; the screenshots ship it as fable-xhigh.)
  2. Pick at least one deliberation backend:
       - codex panel (default, ChatGPT subscription, no API key):
             /plugin marketplace add openai/codex-plugin-cc
             /plugin install codex@openai-codex
       - openrouter (optional): put OPENROUTER_API_KEY in ~/.claude/relentless-inception/secrets.env
       - neither: gates fall to the sanctioned claude-panel floor (still runs)
  3. Invoke from any chat:
         /relentless-inception <your multi-day build task>

Full setup reference: references/setup.md
EOF
