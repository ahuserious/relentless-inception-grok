# Configuration

The complete settings surface is defined by `schemas/config.schema.json` and shown through the configuration skill and MCP tools. There is no separate plugin settings panel.

## Sources and storage

The runtime deep-merges:

1. `config/default.json`;
2. an optional private override selected by `RELENTLESS_INCEPTION_CONFIG`;
3. otherwise the plugin/user data override under `RELENTLESS_INCEPTION_DATA_DIR` or `~/.grok/relentless-inception/config.json`.

Persistent overrides are validated before atomic write and use owner-only permissions. Run evidence defaults to `~/.grok/relentless-inception/runs` unless Grok supplies a plugin data directory.

Use `/relentless-config show`, `/relentless-config schema`, `/relentless-config doctor`, and the underlying `config_show`, `config_schema`, `config_get`, `config_set`, `config_validate`, `doctor`, `provider_models`, and opt-in `provider_test` tools.

## Displayed categories

The schema exposes all major capabilities:

- providers, protocols, endpoint URLs, environment key names, retries, timeouts, concurrency, capabilities, and routing preferences;
- seats, model ids, roles, personas, context bundles, effort, output limits, tools, pricing, and explicit fallbacks;
- panel, optional panel, judge, synthesizer, native Fusion seat, anonymity, context partitioning, quality floor, and bounded escalation;
- plan, pre-execution, post-execution, final, and summarize review gates;
- call/token/tool/time/cost budgets and approval thresholds;
- privacy, egress, redaction, path policies, and evidence requirements;
- rescue, circuit breaker, cancellation, and degradation behavior;
- native Grok host/subagent preferences and execution-handoff policy;
- observability, provenance, raw-artifact retention, and usage reconciliation.

## Frontier-only shipped defaults

Every enabled direct xAI seat uses exact `grok-4.5` at high effort. Native Grok agent definitions and host preferences use `grok-4.5-latest`. Optional Codex configuration uses exact `gpt-5.6-sol`. The profile disables automatic model fallback and router-based replacement.

The schema intentionally accepts arbitrary provider-native model ids. Users may create a cheaper or more diverse profile, but that is an explicit configuration decision and its actual requested/returned model provenance remains in the ledger.

## Provider types

| Type | Wire contract | Default state |
|---|---|---|
| `xai_responses` | xAI Responses | enabled for exact Grok 4.5 seats |
| `openai_responses` | OpenAI Responses | disabled |
| `anthropic_messages` | Anthropic Messages | disabled |
| `openrouter_chat` | OpenRouter Chat Completions/routing | disabled |
| `openrouter_fusion` | OpenRouter Fusion plugin | disabled |
| `openai_compatible_chat` | trusted/private compatible router | disabled |

An enabled provider does not make every seat active. Both the provider and seat must be enabled and referenced by the selected profile. A missing required seat fails visibly; it is never replaced by a weaker model unless the selected profile explicitly permits that route.

## Credentials

Provider configuration contains environment-variable names, never values. The standard names are `XAI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`, and `TRUSTED_ROUTER_API_KEY`.

Optional `secret_env_files` entries must be owner-owned regular files with mode `0600` containing static `NAME=value` lines. Shell expansion and command substitution are rejected. Process environment values take precedence. The runtime never reads Grok's host auth file as a generic API key.

## OpenRouter and trusted routers

OpenRouter per-seat routing and native Fusion parameters remain displayable, including provider order/allowlists, fallback policy, data-collection/ZDR preferences, quantization, throughput/latency/price preferences, analysis models, comparative model, tool-call limits, and reasoning settings.

Those paths were not exercised live in this local campaign because a working OpenRouter credential was unavailable. They remain covered by schema, request-shape, failure, accounting, and mock-response tests. Run `provider_models` and a deliberately budgeted `provider_test` before making a routed seat load-bearing. Native OpenRouter Fusion probing is intentionally refused by the cheap probe because one request can fan out into several billable calls.
