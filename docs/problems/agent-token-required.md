# Agent Token Required

`401 Unauthorized`, `application/problem+json`

The agent gateway (`apim-intplat-agents`) only accepts calls from AI agents with an Entra ID
token for the `intplat-agent-gateway` application, holding its `Agent.Act` app role. Every agent
has its own identity, so every action is attributable to one agent and is audited in the tap.

An identity becomes an agent when a tenant administrator grants it the role
(`azure-landing-zone/bootstrap/agent-gateway-app.sh <principal-object-id>`).

```http
GET /platform/health HTTP/1.1
Host: apim-intplat-agents.azure-api.net
Authorization: Bearer <token for api://<application id>>
Ocp-Apim-Subscription-Key: <the agent's subscription key>
Correlation-Id: ord-4711
```
