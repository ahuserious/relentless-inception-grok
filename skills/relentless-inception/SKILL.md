---
name: relentless-inception
description: Run maximum-intelligence multi-model deliberation, fusion, adversarial review, and verified execution. Use when the user asks for relentless inception, multi-model fusion, a high-stakes implementation, or an end-to-end build that must be proven rather than merely drafted.
when-to-use: relentless inception, multi-model fusion, maximum intelligence, build until verified, adversarially review and execute
argument-hint: task to deliberate, fuse, review, and execute
user-invocable: true
model: grok-4.5
effort: high
compatibility: Requires Grok Build 0.2.106 or newer, Python 3.9 or newer, and environment credentials for every enabled external provider.
metadata:
  author: ahuserious
  short-description: Maximum-intelligence fusion and verified execution
---

# Relentless Inception

Use the `relentless-inception` MCP server as the authoritative control plane. Native Grok work in this workflow always uses exact `grok-4.5` at the highest effort supported by Grok Build 0.2.106 (`high`). With the credentials available for this installation, the active external fusion panel uses exact Grok 4.5; the only shipped optional GPT seat is exact GPT-5.6 Sol and stays disabled until its provider is explicitly configured. Never substitute a weaker model or silently degrade a seat.

## Workflow

1. Discover the server tools with `search_tool` when they are not already visible.
2. Call `relentless-inception__doctor` and `relentless-inception__config_validate`. Stop before billable calls if either reports an invalid configuration or a required credential is absent.
3. Restate the task, acceptance criteria, locked constraints, and available mechanical evidence. Do not send credentials, hidden reasoning, unrelated repository content, or sensitive paths to external providers.
4. Call `relentless-inception__fuse` once with the task, relevant context, mechanical evidence, and an explicitly requested profile if supplied. This call is billable and the MCP runtime owns the bounded panel, comparative judge, synthesis, receipt binding, budget limits, and synthesis gate.
5. Inspect the returned execution handoff. Verify its run ID, payload hash, selected plan, unresolved disagreements, pending lifecycle gates, and required evidence before mutating anything.
6. Run the plan and pre-execution adversarial gates through `relentless-inception__adversarial_gate`. Do not begin mutation until both pass.
7. Execute the approved handoff with Grok Build host tools and, where useful, native subagents defined by this plugin. Keep work scoped to the handoff and preserve the exact evidence packet used for review.
8. Run the post-execution, final, and summarize adversarial gates against the exact artifacts and fresh mechanical evidence. A failed or incomplete gate blocks completion.
9. Report the result with verification evidence, material dissent, provider/model provenance, and remaining limitations. Never describe a draft, an unverified edit, or a passive hook event as a passing gate.

## Non-negotiable boundaries

- Hard gates are enforced by the MCP runtime and explicit MCP gate calls. Grok lifecycle hooks are passive defense-in-depth signals and fail open if their process errors.
- Never read or modify `~/.grok/auth.json`, copy credential values into configuration, or print secrets. Store only environment-variable names such as `XAI_API_KEY`.
- Do not use OpenRouter for a live call unless its configured credential is present and the user has authorized the billable request.
- Do not launch recursive Grok processes from the MCP runtime. Native execution remains visible and host-owned.
- Use `relentless-inception__run_abort` when the user requests cancellation, then confirm the recoverable kill switch was created.
