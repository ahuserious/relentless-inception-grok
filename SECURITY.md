# Security Policy

The detailed trust boundary, credential rules, egress model, state integrity, and execution-safety guidance are maintained in [`docs/SECURITY.md`](docs/SECURITY.md).

Do not open a public issue containing an API key, bearer token, auth file, private Grok session, prompt history, encrypted update stream, local configuration, or provider response that may contain sensitive data. Use GitHub private vulnerability reporting when enabled, or contact the repository owner privately. Rotate a credential immediately if it was pasted into chat, a terminal transcript, or a run log.

When reporting a receipt, resume, gate, or execution-handoff vulnerability, include the plugin version, source commit, Grok Build version, run-ledger schema, minimal redacted reproduction, and whether the issue permits inconsistent artifacts, unaccounted redispatch, model substitution, or mutation authorization bypass. Never attach a private run or session directory wholesale.

The public [Grok fusion artifact](https://github.com/ahuserious/grok-fusion-artifact/tree/limited-cost-2026-07-20) is curated evidence, not a safe destination for new private run data.
