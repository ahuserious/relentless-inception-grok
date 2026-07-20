# Relentless Inception for Grok Build

This repository is the runtime-backed Grok Build plugin. The canonical user workflow is `skills/relentless-inception/SKILL.md`; the hard provider, budget, receipt, and gate logic is under `runtime/`.

## Release invariants

- Target Grok Build 0.2.106 or newer.
- Native Grok agents use `grok-4.5-latest`; direct xAI API seats use exact `grok-4.5`.
- Optional Codex participation uses exact `gpt-5.6-sol`.
- Shipped defaults never select Grok 4.3, GPT-5.6 Terra, a cheaper judge, or an unconfigured router.
- Other provider/model ids remain configurable through the schema; do not hard-code a global allowlist.
- Secrets are environment references only. Never read or copy `~/.grok/auth.json`.
- MCP gates are authoritative. Hooks are defense in depth and fail open on hook errors.
- Preserve unrelated user changes and never force-push.

## Verification

Before claiming completion, run the offline unit suite, compilation, JSON parsing, `grok plugin validate .`, an installed discovery check, and proportionate live provider/harness checks. A plugin manifest pass is not proof that model fusion works.

The legacy `assets/`, `references/`, and `scripts/` trees are provenance only. Do not route v0.4 work through the old shell scaffold or Claude settings installer.
