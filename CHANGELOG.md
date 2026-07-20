# Changelog

## 0.4.0 - 2026-07-20

- Port the receipt-bound, resumable multi-model fusion runtime from the validated
  Codex 0.1.4 implementation.
- Add Grok Build host handoffs, optional hash-bound Grok CLI execution, and a
  Grok-scoped default data directory at `~/.grok/relentless-inception`.
- Ship direct xAI Grok 4.5 as every active panel, judge, synthesis, and gate seat;
  ship `grok-4.5-latest` for native Grok execution and review metadata.
- Keep the optional GPT seat pinned to `gpt-5.6-sol`; remove weaker default model
  fallbacks. OpenRouter, OpenRouter Fusion, trusted-router, OpenAI, and Anthropic
  adapters remain explicit opt-ins.
- Add dependency-free configuration, provider, orchestration, receipt-integrity,
  execution-handoff, MCP, and state tests.
- Replace the retired flat-skill installer and stale compatibility manifest with
  the Grok Build plugin install path, preserving legacy checkouts on conflict.
- Pin native Grok handoff and review preferences to `max` effort.
