---
name: relentless-inception-legacy-pointer
description: Compatibility pointer for the retired flat-skill installation. Install the canonical Grok Build plugin and use its nested relentless-inception skill instead.
user-invocable: false
disable-model-invocation: true
---

# Legacy flat-skill pointer

The v0.4 Grok Build implementation lives at `skills/relentless-inception/SKILL.md` and is backed by the bundled MCP runtime declared in `.mcp.json`.

Do not run the legacy shell orchestrator or install its Claude settings hooks. Validate and install this repository as a Grok plugin:

```bash
grok plugin validate /absolute/path/to/relentless-inception-grok
grok plugin install /absolute/path/to/relentless-inception-grok --trust
```

Then invoke `/relentless-inception` from Grok Build.
