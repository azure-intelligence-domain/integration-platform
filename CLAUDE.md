# CLAUDE.md

The shared foundation of the integration platform (ADR 0010). Ground rules, cost rules and
decisions live in the
[ai-intelligence-domain](https://github.com/azure-intelligence-domain/ai-intelligence-domain)
repository.

- Contract first: change `openapi.yaml` before the policy or infrastructure that implements it,
  and raise `info.version` on every contract change (the contract check enforces it).
- Never weaken the global policy's `Correlation-Id` check or the Log Analytics daily cap.
- Consumption and pay-per-use tiers only; no keys or connection strings (`disableLocalAuth`).
- Names are fixed and match the shared landscape in the `contracts` repository; other
  building blocks derive them, so renaming is a breaking change.
- Policies must stay well-formed XML (single-quote attributes that contain C# strings).
