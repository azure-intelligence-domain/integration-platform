# Platform Token Required

- **Status:** 401
- **Returned by:** `apim-intplat-demo`, products `system-apis` and `process-apis` (every System and Process API)

Process and System APIs are internal: only building blocks call them, never people or websites
(they use the Experience APIs). The caller
presents an Entra ID token for the `intplat-platform-apis` application (audience
`api://e3337087-144a-4b2e-8faa-c802660b9dee`), issued to its runtime identity, and that identity is
on the platform's allow-list ([`routing/internal-callers.yaml`](../../routing/internal-callers.yaml)).

```json
{
  "type": "https://github.com/azure-intelligence-domain/integration-platform/blob/main/docs/problems/platform-token-required.md",
  "title": "Platform Token Required",
  "status": 401,
  "detail": "Process and System APIs are called by building blocks only, with an Entra ID token for the intplat-platform-apis application, from a client on the platform's allow-list.",
  "instance": "/salesforce/orders/4711"
}
```

**Fix:** request a token for `api://e3337087-144a-4b2e-8faa-c802660b9dee` with the building block's
runtime identity, and add that identity to `routing/internal-callers.yaml` (a pull request to the
platform team).
