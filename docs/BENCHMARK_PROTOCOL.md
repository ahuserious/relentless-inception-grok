# Benchmark Protocol

Terminal-Bench and DeepSWE are future physical integration gates for the Grok Build host. Publishing a jig or passing unit tests does not change a harness row from `not run`.

## Required evidence layers

A complete host-harness claim requires all of the following:

1. the task harness reports its verifier reward and detailed pass/fail counts;
2. the Grok host session shows the intended exact model and effort, with all cancelled/failed attempts retained;
3. the Relentless Inception run contains the required fusion and lifecycle stages, exact requested/actual provider models, receipt chain, cost/usage status, artifact hashes, and gates;
4. a version-pinned validator accepts source, harness, image, event-order, model-roster, and outcome contracts.

A task reward, native-agent verdict, provider fusion gate, packaging check, or mocked response cannot substitute for another layer.

## Host boundary

Grok Build owns workspace access, native subagents, terminal actions, worktrees, permissions, mutation, tests, and user approvals. External provider seats receive only a bounded evidence packet and cannot inspect the task container or call Grok's local tools. The host must collect mechanical evidence without exposing hidden solutions or verifier internals.

## Campaign rules

- Pin Grok Build version/build, plugin commit/tree, harness/dataset commit, task base commit, image digest, native requested model/effort, and provider requested/actual models.
- Use one fresh private output directory per attempt and no hidden harness retries.
- Set provider, host, time, token, tool, and cost limits before starting.
- Keep task reward and fusion/lifecycle acceptance in separate fields.
- Publish zero, partial, timeout, cancelled, transport-failed, parser-blocked, and gate-rejected results honestly.
- Require an explicit `--execute` or equivalent opt-in for billable jigs.
- Curate public evidence from an allowlist; never publish auth state or raw private sessions.

## Current status

The 2026-07-20 limited-cost Grok Build campaign completed direct-xAI and native-agent smokes only. Terminal-Bench and DeepSWE remain `not run with Grok Build host`. The immutable [artifact repository](https://github.com/ahuserious/grok-fusion-artifact/tree/limited-cost-2026-07-20) is the source of truth for that status.
