---
name: relentless-config
description: Display, explain, validate, and safely update every Relentless Inception fusion setting. Use for /relentless-config, provider or model selection, panel composition, review gates, budgets, routing, privacy, retries, or diagnostics.
when-to-use: relentless config, fusion settings, choose fusion models, configure providers, configure review gates, fusion doctor
argument-hint: show, doctor, validate, get PATH, schema, or set PATH VALUE
user-invocable: true
model: grok-4.5
effort: high
compatibility: Requires the relentless-inception MCP server bundled with this plugin.
metadata:
  author: ahuserious
  short-description: Display and safely configure every fusion setting
---

# Relentless Configuration

Use only the `relentless-inception` MCP configuration tools. They expose the merged settings, complete schema, safe overrides, and credential-presence diagnostics without displaying secrets.

## Route the request

- `show`: call `relentless-inception__config_show` and render the redacted result clearly.
- `schema`: call `relentless-inception__config_schema`; explain the requested sections and enumerate allowed values.
- `get PATH`: call `relentless-inception__config_get` with the exact dotted path.
- `set PATH VALUE`: show the intended change, call `relentless-inception__config_set`, then call `relentless-inception__config_validate` and display the effective redacted value.
- `validate`: call `relentless-inception__config_validate` and report every error without hiding cross-reference failures.
- `doctor`: call `relentless-inception__doctor`; report provider enablement and credential presence, never credential values.
- Provider catalog lookup: explain that it makes a network request, then call `relentless-inception__provider_models` only when the user requested current models.
- Provider ping: explain that it is billable, then call `relentless-inception__provider_test` only with explicit user intent.

## Smartest-model defaults

Preserve the maximum-intelligence defaults unless the user explicitly changes them: native Grok work is exact `grok-4.5` at the highest effort supported by Grok Build 0.2.106 (`high`); every active direct xAI fusion seat is exact Grok 4.5; and the disabled, explicitly enabled GPT option is exact GPT-5.6 Sol. Never introduce a weaker fallback or silent model degradation.

Reject plaintext API keys, tokens, passwords, cookies, and auth-file contents. Configuration may name environment variables such as `XAI_API_KEY` or `OPENROUTER_API_KEY`; it must not store their values. Never inspect or edit `~/.grok/auth.json`.
