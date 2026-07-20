# Changelog

## Unreleased

- Published a separate checksummed limited-cost artifact with direct-xAI receipts, curated native Grok Build telemetry, failed preflight attempts, opt-in reproduction jigs, and explicit claim boundaries.
- Added release-evidence and benchmark-protocol documentation that marks Terminal-Bench and DeepSWE as not run with Grok Build as host.
- Added network-free GitHub CI and a manifest-version parity regression; aligned the compatibility manifest with runtime version 0.4.1.
- Clarified that 0.4.1 was validated on Grok Build 0.2.106 and that newer hosts require compatibility retesting.

## 0.4.1 - 2026-07-20

- Align every native agent, skill, command, host handoff, and recursive execution
  contract with the live Grok Build 0.2.106 catalog: exact `grok-4.5` at `high`,
  its strongest supported reasoning effort.
- Replace the unavailable `grok-4.5-latest`, `xhigh`, and `max` native settings;
  keep broader effort values available only for provider adapters that support them.
- Use Grok Build's installed plugin-agent namespace in the default review role and
  document `relentless-inception-grok:adversarial-review` for native launches.
- Add package and schema regressions for model metadata, namespaced reviewer roles,
  and unsupported native effort values.

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
