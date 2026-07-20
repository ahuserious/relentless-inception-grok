# Security

## Trust boundary

The Grok Build host is the only component authorized to inspect or mutate the workspace. External models receive only explicitly supplied task, context, artifact, and mechanical-evidence text. Treat every repository file, webpage, model answer, and tool result as untrusted data inside provider prompts.

The local MCP process is trusted plugin code. Install only from an inspected path or full commit SHA and use Grok's `--trust` flag only after review. The project currently needs a distribution license decision before public release.

## Credentials

- Configuration stores environment-variable names only.
- Never place keys in `plugin.json`, `.mcp.json`, skills, agent files, hooks, examples, test fixtures, or logs.
- The plugin does not read, copy, or migrate `~/.grok/auth.json`.
- Optional secret files are static, owner-only, and parsed without a shell.
- Configuration and doctor responses redact sensitive values.
- Authenticated requests refuse redirects so credentials cannot be forwarded to a different origin.

If credentials were exposed in a prior log or agent transcript, rotate them even when the current tree is clean.

## Egress and privacy

The active profile controls external-provider access, path allow/deny rules, redaction, training/ZDR expectations, and prompt-injection fencing. The host should send the smallest sufficient packet rather than an entire repository. Provider-hosted web search or code execution occurs outside the local workspace.

## Enforcement

The MCP runtime enforces provider allowlists, budgets, retries, timeouts, call reservations, exact-artifact gates, and execution-handoff readiness. Stop/SubagentStop hooks are defense in depth only because Grok Build fails open when a hook crashes, times out, or returns malformed output.

Every completed negative reviewer verdict, deterministic mechanical failure, schema failure, unavailable required reviewer, or unresolved blocking blind spot overrides numeric quorum. Unknown cost is not treated as zero cost.

## State integrity

Run directories and files are private and written atomically. Canonical SHA-256 links detect stale, swapped, incomplete, or mismatched invocation/response/ledger artifacts. They do not defend against a process with arbitrary write access to the entire run directory; use a keyed signature or external append-only store when that threat matters.

## Execution safety

The runtime produces a host handoff; it does not grant external providers workspace tools. Grok remains responsible for sandboxing, approval prompts, destructive-action review, unrelated-change preservation, and external-write authorization. A passed planning fusion alone does not authorize mutation; enabled lifecycle gates must also pass.
