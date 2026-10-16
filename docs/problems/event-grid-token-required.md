# Event Grid Token Required

`401 Unauthorized`, `application/problem+json`. Returned by the [Event Intake API](../../intake.openapi.yaml).

Only Event Grid delivers events, with the managed identity of a platform topic and an Entra ID token
for the `intplat-platform-apis` application. Nobody else can post events into a consumer.
