# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- The `localMint` value for `mcpServers[].auth.mode` (and its `auth.audience` key). muster removes the `auth.localMint` MCPServer CRD field (giantswarm/muster#947), so the mode would render CRs the admission webhook rejects. Entries using it switch to `mode: forward`: muster forwards the validated caller token unchanged and the backend validates it against muster's JWKS via its `trustedIssuers` config. The audience the backend must accept is muster's `resourceIdentifier`; set `auth.audiences` (or `defaults.audiences`) accordingly.

## [0.5.0] - 2026-06-18

### Fixed

- `oauthMode: validate` now attaches the inbound JWT `AgentgatewayPolicy` to this
  chart's MCP `HTTPRoute` instead of the shared agentgateway `Gateway`. Targeting the
  Gateway applied `Strict` JWT validation to every route on it, including routes owned
  by other charts (e.g. klaus, which serves the Slack events webhook that authenticates
  by signature, not JWT), returning 401 on traffic that should never have been gated.

## [0.4.0] - 2026-06-16

### Added

- `identityProviders.<name>.expectedIssuer` — pins the `iss` claim of the RFC 8693
  exchanged token, rendered into the muster MCPServer `tokenExchange.expectedIssuer`.
  Required when `tokenEndpoint` points at a transport-only proxy (e.g. a tunnelport
  `:8443` in-cluster Service) whose URL differs from the remote Dex issuer: the minted
  token still carries the public Dex issuer, so muster must be told what to expect.
  Lets gazelle repoint its tunneled MCP servers to private clusters purely through
  sub-chart values instead of raw `MCPServer` CRs (giantswarm#36883).

## [0.3.0] - 2026-06-11

### Added

- `agentgateway.jwt.extraProviders` — additional JWT providers for the inbound
  `jwtAuthentication` policy (oauthMode `validate`), rendered after the primary provider.
  Lets the gateway accept tokens from a second issuer at the edge, e.g. Dex-issued ID
  tokens forwarded by Backstage AI chat alongside muster-issued JWTs (giantswarm#36840).
  Cross-namespace `jwks` backendRefs require a ReferenceGrant in the target namespace.

### Fixed

- `values.schema.json` no longer rejects every `identityProviders` entry. The schema declared
  `identityProviders` as an object with `additionalProperties: false` and no properties, so any
  populated map failed validation (`helm install`/`ct lint`) and `auth.mode: exchange` was
  impossible to configure. `identityProviders` now carries a per-provider value schema
  (`tokenEndpoint` required; `connectorId`, `scopes`, `credentialsSecret` optional).

## [0.2.0] - 2026-06-03

### Added

- `agentgateway.viaMuster` — via-muster topology: `client → agentgateway → muster → N MCP servers`.
  agentgateway becomes the single MCP choke point for observability (per-call metrics, traces,
  access logs with `protocol=mcp`, tool name, session id, latency). muster keeps all per-server
  connection logic, OAuth, and RFC 8693 token exchange. Renders:
  - `AgentgatewayBackend` — single target pointing at muster's aggregator endpoint with
    `auth.passthrough` (token forwarded to muster unchanged; muster is the enforcement point).
  - `HTTPRoute` — connects the agentgateway data-plane Gateway to the Backend.
  - `HTTPRoute` (`-prm`) — proxies `agentgateway-host/.well-known/oauth-protected-resource[/mcp]`
    to the muster Service using a standard `gateway.networking.k8s.io HTTPRoute` (no Envoy-specific
    extensions). muster serves the correct doc because `muster.oauth.server.resourceIdentifier`
    is set to the agentgateway hostname in shared-configs.
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

[Unreleased]: https://github.com/giantswarm/agentic-platform-mcps/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/giantswarm/agentic-platform-mcps/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/giantswarm/agentic-platform-mcps/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/giantswarm/agentic-platform-mcps/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/giantswarm/agentic-platform-mcps/releases/tag/v0.1.0
