# Correlation Id Required

`400 Bad Request`, `application/problem+json`

Every call through the platform's gateway must carry a `Correlation-Id` header: the business
journey the call belongs to, for example `ord-4711`. It has the same format as the
`correlationid` attribute of the event envelope: lowercase letters and digits separated by
hyphens, at most 64 characters.

API Management enforces this for every API with one global policy
([`people-gateway.xml`](../../infra/policies/people-gateway.xml), [`agent-gateway.xml`](../../infra/policies/agent-gateway.xml)), so synchronous calls and
events of the same journey can always be connected.

```http
GET /platform/health HTTP/1.1
Host: apim-intplat-demo.azure-api.net
Ocp-Apim-Subscription-Key: <key>
Correlation-Id: ord-4711
```
