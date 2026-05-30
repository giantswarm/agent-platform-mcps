# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `agentgateway.viaMuster` — via-muster topology: `client → agentgateway → muster → N MCP servers`.
  agentgateway becomes the single MCP choke point for observability (per-call metrics, traces,
  access logs with `protocol=mcp`, tool name, session id, latency). muster keeps all per-server
  connection logic, OAuth, and RFC 8693 token exchange. Renders:
  - `AgentgatewayBackend` — single target pointing at muster's aggregator endpoint with
    `auth.passthrough` (token forwarded to muster unchanged; muster is the enforcement point).
  - `HTTPRoute` — connects the agentgateway data-plane Gateway to the Backend.
  - `HTTPRouteFilter` + `HTTPRoute` — serves a corrected `/.well-known/oauth-protected-resource`
    doc at `agentgateway.host` with `resource=agentgateway-host/mcp` and
    `authorization_servers=[muster-host]`. Required because muster's own doc advertises
    `resource=muster-host`, which would cause an MCP SDK resource-mismatch error for clients
    dialling the agentgateway hostname.
  - Public ingress `HTTPRoute` and `BackendTrafficPolicy` are owned by the `agentic-platform`
    umbrella chart (`gateway.httpRoute` / `gateway.backendTrafficPolicy`), not this chart.
- `agentgateway.oauthMode` (`passthrough` | `validate`, default `passthrough`):
  - `passthrough` — agentgateway forwards tokens to muster without validating them. muster is
    the sole enforcement point. The well-known shim is served regardless.
  - `validate` — additionally renders an `AgentgatewayPolicy` with generic
    `jwtAuthentication.providers[]` (any OIDC issuer; no Auth0/Keycloak preset required).
    agentgateway validates the inbound token at the edge before forwarding to muster. muster
    still validates as a second layer. Token exchange is unaffected: agentgateway only sees
    the inbound user token; muster performs all downstream RFC 8693 exchanges internally.
    Requires `agentgateway.jwt.*` and a `ReferenceGrant` in `jwksBackendRef.namespace`
    (platform prerequisite, not rendered by this chart).

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
