#!/usr/bin/env bash
#
# relentless-inception-grok — one-shot installer (flat-clone path, Grok Build edition).
#
# This installs the skill directory into ~/.grok/skills and scaffolds the
# user config. It is idempotent: existing config is never overwritten.
#
# Grok Build also scans ~/.claude/skills/ zero-config, so
#     RI_SKILL_DIR="$HOME/.claude/skills/relentless-inception-grok"
# is a valid alternate target — but prefer the default: within Grok's user tier
# ~/.grok/skills/ outranks ~/.claude/skills/, and Claude Code never scans ~/.grok/,
# so both editions coexist cleanly.
#
# Prefer the plugin path if you want managed updates:
#     grok plugin install ahuserious/relentless-inception-grok --trust
#
# Overridable env vars: RI_SKILL_DIR, RI_CONFIG_DIR, RI_REPO
set -euo pipefail

SKILL_DIR="${RI_SKILL_DIR:-$HOME/.grok/skills/relentless-inception-grok}"
CONFIG_DIR="${RI_CONFIG_DIR:-$HOME/.claude/relentless-inception-grok}"
REPO="${RI_REPO:-https://github.com/ahuserious/relentless-inception-grok}"

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
  echo "    wrote secrets.env (chmod 600) — only needed for the provider-direct transports"
else
  echo "    secrets.env exists; kept"
fi

echo "==> Preflight (tool checks + live model-seat probes); non-fatal"
if ! bash "$SKILL_DIR/scripts/check_prereqs.sh"; then
  echo "!! Preflight flagged issues above. The skill is still installed; resolve them before a real run."
fi

cat <<'EOF'

Done. To finish setup:
  1. Make sure Grok Build is signed in:
         grok login          (SuperGrok or X Premium+; headless box: grok login --device-auth)
  2. Wire up seats for the default three-vendor panel (each optional; missing seats
     degrade per the recorded ladder, and with none the gates still run on the native
     grok-panel floor):
       - xai direct (panel expert, grok-4.5 @xhigh): put XAI_API_KEY in
             ~/.claude/relentless-inception-grok/secrets.env
       - codex (gpt-5.6-sol seat, ChatGPT subscription): npm i -g @openai/codex && codex login
       - claude-cli (fable-5 panel/judge/fuser seats, Claude subscription): install the
         `claude` CLI and sign in. Without it, the fuser falls back to `grok-session` —
         then run your session on your strongest Grok model (grok -m grok-4.5 --effort xhigh).
  3. Invoke from any chat:
         /relentless-inception <your multi-day build task>

Full setup reference: references/setup.md
EOF
