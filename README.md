Test Red-Teaming using our CI/CD

Usage notes for callbacks:

- Preferred: set `RECEIVER_WEBHOOK_URLS` (secret) to a comma-separated list of public HTTPS webhook endpoints (e.g., your receiver + any extra sinks). The push workflow will pass these via `callback_urls`.
- Backward-compatible: if `RECEIVER_WEBHOOK_URLS` is not set, set `RECEIVER_WEBHOOK_URL` (single URL). The workflow will use that instead.
- Manual workflow: you can provide `callback_urls` (comma-separated) or `callback_url` (single) as inputs; `callback_urls` takes precedence.

Required repo configuration:

- Secrets: `TESTSAVANT_API_KEY`, and either `RECEIVER_WEBHOOK_URLS` or `RECEIVER_WEBHOOK_URL`. If your receiver forwards to GitHub, also set `TS_GITHUB_TOKEN` in the receiver environment (not here).
- Variables: `REDTEAMING_ID` (UUID of the configuration).

Listener workflow:

- `.github/workflows/on-dispatch.yml` reacts to `repository_dispatch` events sent by your webhook receiver on final run events.