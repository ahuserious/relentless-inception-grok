# Release Evidence

This page defines exactly what was observed for version 0.4.1 and what remains unverified. The public evidence package is immutable at [`ahuserious/grok-fusion-artifact@limited-cost-2026-07-20`](https://github.com/ahuserious/grok-fusion-artifact/tree/limited-cost-2026-07-20).

## Claim boundary

The campaign was deliberately limited by API cost. It is an engineering acceptance sample, not a leaderboard or a statistically powered comparison. No repeated task sample, matched solo baseline, confidence interval, blinded grader, or significance test was run.

## Environment

| Surface | Observed value |
|---|---|
| Plugin version | `0.4.1` |
| Tested feature commit | `4c9c64712cf4d34cc7a221d04ce857260ac3dccb` |
| Merged release commit | `1a5321b49ce1695701cf64bbb9c3429b2c6c917a` |
| Tested/merged tree | `1b5c10ef0835d8c6f5eb9db9aa45bac3e8d3e3c3` |
| Grok Build | `0.2.106 (bde89716f679)` |
| Tested source tree SHA-256 | `b79e1624b60cad40a1f0995b15a7ee314aa353c3cf731187ee38843368cb9ffa` |
| Installed tree SHA-256 | `b79e1624b60cad40a1f0995b15a7ee314aa353c3cf731187ee38843368cb9ffa` |
| Offline suite | 168 tests passed on the publishing branch; compilation, JSON parsing, and `grok plugin validate .` also passed |

The source/installed tree hash above identifies the package used for the native smoke. The publishing branch adds documentation, CI, a compatibility-manifest parity fix, and its regression without changing provider or orchestration code; the immutable release tag identifies that final publication tree.

## Provider and host matrix

| Surface | Offline/mock coverage | Live campaign | Release claim |
|---|---:|---:|---|
| Direct xAI Responses | Yes | Yes | Exact Grok 4.5 fusion completed |
| Native Grok Build profile | Package/discovery tests | Yes | Structured pass after one visible cancelled attempt |
| Direct OpenAI Responses | Yes | No | Implemented, not live-accepted here |
| Direct Anthropic Messages | Yes | No | Implemented, not live-accepted here |
| OpenRouter chat | Yes | No funded credential | No live claim |
| OpenRouter native Fusion | Yes | No funded credential | No live claim; cheap probe refuses fan-out |
| Trusted/private compatible router | Yes | No | Contract/mock coverage only |
| Terminal-Bench with Grok host | Jig/protocol only | No | Not run |
| DeepSWE with Grok host | Jig/protocol only | No | Not run |

## Direct xAI fusion

Run `grok-040-frontier-smoke-003` completed from `2026-07-20T05:36:35Z` to `05:40:54Z` on the 0.4.0 release-candidate external path. Version 0.4.1 later changed native model/effort metadata and schema constraints, not provider or orchestration code.

| Property | Retained value |
|---|---:|
| Calls | 7 |
| Requested/actual model | exact `grok-4.5` for every call |
| Panel/judge/synthesizer/gate | 3 / 1 / 1 / 2 |
| Gate | 2/2 `PASS` |
| Gated synthesis SHA-256 | `c6dd3c8ae4da342592dab0814a9f1020288fa0e2a3dd17806532c286306d627a` |
| Input/output/reasoning tokens | 34,254 / 19,208 / 6,196 |
| Total/cached tokens | 53,462 / 896 |
| Known cost | $0.1822328 |
| Unknown-cost/tool calls | 0 / 0 |

The handoff correctly remained mutation-unauthorized while host plan and pre-execution gates were pending.

## Native Grok Build smoke

Both attempts requested exact `grok-4.5` at `high`. Host telemetry reported the served implementation as `grok-4.5-build`.

| Attempt | Stop | Input/output/reasoning | Cost | Result |
|---|---|---:|---:|---|
| 1 | `cancelled` | 63,580 / 195 / 42 | $0.1224548 | Tool path consumed the single turn; no verdict |
| 2 | `end_turn` | 65,322 / 975 / 879 | $0.1349708 | Required structured `pass` |

Native total was $0.2574256; combined selected direct/native spend was $0.4396584. Raw sessions remain private because they contain system/project prompts, tool payloads, encrypted update material, and local context. The artifact publishes SHA-256 commitments and curated telemetry instead.

## Visible preflight failures

- `grok-040-frontier-smoke-001`: missing API credential; zero calls and zero cost.
- `grok-040-frontier-smoke-002`: transport/DNS failure; nine attempts, no completed response entries, and zero recorded token/cost usage.

Neither is a model-quality result. Both remain public as fail-closed diagnostics.

## Cross-model and benchmark status

The completed external fusion used role-diverse Grok 4.5 calls, not several model families. No optional GPT, Claude, OpenRouter, or TrustedRouter seat participated. No Terminal-Bench or DeepSWE task was executed with Grok Build as the host. These statuses remain `not run` until a funded physical campaign publishes receipts.
