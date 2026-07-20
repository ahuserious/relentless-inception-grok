# Contributing

Keep changes surgical and evidence-backed. New provider behavior needs deterministic request/response, failure, usage, cost, retry, and provenance tests without live network calls. New configuration fields must be documented in `schemas/config.schema.json`, represented in the default or an example, and either enforced by the responsible runtime/host layer or labeled informational.

Before submitting a change:

```bash
python3 -m unittest discover -s tests -v
python3 -m compileall -q runtime tests
python3 -m json.tool plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool .mcp.json >/dev/null
python3 -m json.tool config/default.json >/dev/null
python3 -m json.tool schemas/config.schema.json >/dev/null
grok plugin validate .
git diff --check
```

Do not commit credentials, auth files, `.env` files, private session material, local overrides, run outputs, or unreviewed provider responses. Do not weaken receipt binding, exact-artifact gates, author/reviewer separation, cost accounting, or the external-seat/workspace boundary without an explicit security review.

A live run is billable and must be opt-in. Report requested and actual models, host version, cost/usage completeness, all failed/cancelled attempts, and any untested provider or harness. Never turn a packaging pass, mock response, or intermediate gate into a live release pass.
