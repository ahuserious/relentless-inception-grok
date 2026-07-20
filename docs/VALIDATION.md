# Validation

Validation is layered because no single check proves the whole plugin.

## Offline runtime

```bash
python3 -m unittest discover -s tests -v
python3 -m compileall -q runtime tests
python3 -m json.tool plugin.json >/dev/null
python3 -m json.tool .mcp.json >/dev/null
python3 -m json.tool config/default.json >/dev/null
git diff --check
```

The suite covers schema enforcement, credential redaction, provider request/response parsing, redirects, retries, semantic failures, usage and cost accounting, concurrency, atomic persistence, invocation receipts, resume tampering, panel collapse, minority blocking verdicts, exact-hash review, and execution handoff.

## Grok package discovery

```bash
grok plugin validate .
grok plugin install /absolute/path/to/relentless-inception-grok --trust
grok plugin list --json
grok plugin details relentless-inception-grok
grok inspect --json
```

Acceptance requires all three skills, every intended agent with valid frontmatter, bundled hooks, and the MCP server to be discovered. Host-side subagent discovery must report namespaced IDs such as `relentless-inception-grok:adversarial-review`. Grok Build 0.2.106's top-level `--agent` lookup does not consistently resolve that namespace; use the installed agent-profile file for a headless launch and treat the discovered namespace as the host/subagent identifier. A valid manifest with zero skill directories is a failure.

## MCP startup

```bash
grok mcp doctor relentless-inception --json
```

Then use `/relentless-config doctor` and, when billable access is explicitly intended, `provider_models` or `provider_test`. A provider presence check is not a completion call.

## Live fusion

A retained live proof must identify every requested and actual model, provider, stage, attempt, response receipt, cost/usage status, synthesis author, exact artifact hash, and gate verdict. Direct xAI defaults and native agent definitions must show only exact `grok-4.5`; native Grok Build invocations must use `high`, the strongest supported effort in 0.2.106.

OpenRouter is not part of the local live acceptance campaign when no working credential is available. Do not convert mocked adapter coverage into a live-provider claim.

## Task harnesses

Terminal-Bench and DeepSWE checks are expensive end-to-end integration tests. A task reward proves the implementation result; the Relentless Inception evidence validator separately proves that all required fusion and lifecycle calls completed with exact receipts. Report these outcomes separately when one passes and the other fails.

The reduced local release campaign runs one problem from each harness per host. No retries or duplicate paid calls are hidden. Any harness timeout, missing lifecycle call, or deterministic gate block stays visible in the evidence record.
