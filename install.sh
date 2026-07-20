#!/usr/bin/env bash
# Install the current runtime-backed Grok Build plugin from this checkout.
set -euo pipefail

PLUGIN_NAME="relentless-inception-grok"
PLUGIN_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LEGACY_SKILL="${HOME}/.grok/skills/${PLUGIN_NAME}"

if ! command -v grok >/dev/null 2>&1; then
  echo "grok is required; install or update Grok Build first" >&2
  exit 1
fi

if [ -e "$LEGACY_SKILL" ]; then
  cat >&2 <<EOF
Legacy flat skill detected at:
  $LEGACY_SKILL

Move it outside ~/.grok/skills before installing so two packages do not claim
the relentless-inception skill name. Preserve local changes; do not delete it.
EOF
  exit 2
fi

grok plugin validate "$PLUGIN_ROOT"

if grok plugin details "$PLUGIN_NAME" >/dev/null 2>&1; then
  cat <<EOF
$PLUGIN_NAME is already installed.

For a local checkout, Grok Build may retain an installed snapshot. To refresh
it while preserving plugin data, run:
  grok plugin uninstall $PLUGIN_NAME --confirm --keep-data
  grok plugin install "$PLUGIN_ROOT" --trust
EOF
  exit 0
fi

grok plugin install "$PLUGIN_ROOT" --trust
grok mcp doctor relentless-inception

cat <<'EOF'

Installed. In Grok Build, run:
  /relentless-config doctor
  /relentless-inception <task>

Provider credentials are opt-in environment references. Never place plaintext
keys in the repository or plugin manifest.
EOF
