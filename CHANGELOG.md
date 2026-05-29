# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `agentgateway.viaMuster` — front muster instead of connecting to each server directly. When
  enabled, the `AgentgatewayBackend` renders a single target pointing at muster's aggregator MCP
  endpoint (`agentgateway.musterUrl`), so traffic flows `client → agentgateway → muster → servers`.
  agentgateway becomes the single MCP choke point for observability while muster keeps doing
  per-server connection + auth + RFC 8693 exchange. The verified inbound token is forwarded to
  muster via `auth.passthrough`; the per-target exchange policies and the `tokenExchange` broker
  are not rendered in this mode. Requires `muster.enabled: true`.

## [0.1.0] - 2026-05-29

### Added

- abstract, vendor-neutral input — `mcpServers` entries use `cluster` / `group` / `url` and
  a single `auth.mode` (`none` | `oauth` | `forward` | `exchange`); the chart owns translation to
  each CRD. Token-exchange / IdP config is factored into a reusable `identityProviders` map
  referenced by `auth.provider`, and `muster.families` declares which groups muster aggregates.
- render muster `MCPServer` CRs from the `mcpServers` list (`muster.enabled`). Verified a
  semantically identical drop-in for the hand-written files it replaces, across all four auth modes.
- render agentgateway configuration (`AgentgatewayBackend` + `AgentgatewayPolicy`)
  from the same list (`agentgateway.enabled`):
  - `auth.mode: forward` → target `static.policies.auth.passthrough` (same-cluster only).
  - `auth.mode: exchange` → a per-target `AgentgatewayPolicy` attached to the backend via
    `sectionName`, with `backend.extAuth` → muster broker and the target's cluster + provider
    fields passed in `grpc.contextExtensions` (so multiplexed remote clusters each get a token
    valid for their own Dex).
  - `https://` upstreams get `static.policies.tls: {}` so agentgateway originates TLS to remote
    MCP routes.
  All shapes validated server-side against the live `agentgateway.dev` CRDs on a management cluster. The
  `Gateway`, `HTTPRoute` (routing) and inbound caller (JWT) validation are owned by the
  agentgateway deployer, not this chart — it emits no resource that references a `Gateway`.

[Unreleased]: https://github.com/giantswarm/agentic-platform-mcps/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/giantswarm/agentic-platform-mcps/releases/tag/v0.1.0
