# Staff Sign-In Required

- **Status:** 401
- **Returned by:** `apim-intplat-demo`, products `webshop`, `customer-service` and `partners` (the
  Experience APIs staff use)

Staff use the Experience APIs through the [customer portal](https://github.com/azure-intelligence-domain/customer-portal),
signed in with Google: the call carries a Google ID token for the portal's OAuth client, of a Google
Workspace account of the staff domain ([`routing/staff.yaml`](../../routing/staff.yaml), ADR 0017).
Building blocks on the platform's allow-list (the journey test) use an Entra ID token for the
`intplat-platform-apis` application instead.

```json
{
  "type": "https://github.com/azure-intelligence-domain/integration-platform/blob/main/docs/problems/staff-sign-in-required.md",
  "title": "Staff Sign-In Required",
  "status": 401,
  "detail": "Sign in with a Google account of the staff domain, through the customer portal.",
  "instance": "/webshop/orders"
}
```

**Fix:** sign in to the portal again (a Google ID token lasts an hour), with an account of the
staff domain.
