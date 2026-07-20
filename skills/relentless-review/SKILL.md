---
name: relentless-review
description: Run a strict independent adversarial gate over an exact artifact and its mechanical evidence. Use for /relentless-review, plan review, pre-execution authorization, post-execution verification, final review, or summary fidelity review.
when-to-use: relentless review, adversarial gate, review this plan, verify this implementation, final evidence gate, summary fidelity
argument-hint: artifact or review task
user-invocable: true
model: grok-4.5-latest
effort: max
compatibility: Requires the relentless-inception MCP server and configured reviewer seats.
metadata:
  author: ahuserious
  short-description: Exact-artifact adversarial review gate
---

# Relentless Review

Run review as an independent blocking gate, not as supportive commentary.

1. Identify the lifecycle stage: plan, pre-execution, post-execution, final, or summarize.
2. Freeze the complete artifact text and collect current mechanical evidence. Do not paraphrase either before submission.
3. Call `relentless-inception__adversarial_gate` with the exact task label, exact artifact, evidence, and an explicitly selected profile only when the user provided one.
4. Inspect receipt hashes, reviewer provenance, blocking findings, minority findings, and the pass/fail decision.
5. On failure, apply only justified fixes, regenerate mechanical evidence, and submit the complete revised artifact as a new bounded review. Never relabel a failure as advisory.
6. On pass, report what was reviewed, the bound artifact hash, the evidence used, dissent that remains non-blocking, and which lifecycle gate was satisfied.

Native Grok reviewers use `grok-4.5-latest` at `max` effort. Active direct xAI reviewers use exact Grok 4.5; the shipped GPT-5.6 Sol seat is optional and disabled until its provider is explicitly configured. Never silently fall back to a weaker model. Passive lifecycle hooks are audit signals only and do not satisfy this gate.
