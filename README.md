[![CircleCI](https://dl.circleci.com/status-badge/img/gh/giantswarm/agentic-platform-mcps/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/giantswarm/agentic-platform-mcps/tree/main)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/giantswarm/agentic-platform-mcps/badge)](https://securityscorecards.dev/viewer/?uri=github.com/giantswarm/agentic-platform-mcps)

[Guide about how to manage an app on Giant Swarm](https://handbook.giantswarm.io/docs/dev-and-releng/app-developer-processes/adding_app_to_appcatalog/)

# agentic-platform-mcps chart

Giant Swarm offers a agentic-platform-mcps App which can be installed in workload clusters.
Here, we define the agentic-platform-mcps chart with its templates and default configuration.

**What is this app?**

It renders the **configuration** of MCP server connections from a single list in
`values.yaml` into the custom resources consumed by either
[muster](https://github.com/giantswarm/muster) (`muster.giantswarm.io/v1alpha1`
`MCPServer`) or [agentgateway](https://agentgateway.dev) (`agentgateway.dev/v1alpha1`
`AgentgatewayBackend` + `AgentgatewayPolicy`) — or both at once.

This chart deploys configuration only. The data-plane wiring — the agentgateway
`Gateway`, the `HTTPRoute` that exposes it, and inbound caller (JWT) validation —
is owned by whoever deploys the agentgateway, not by this chart.

**Why did we add it?**

The MCP server connections used to be ~50 near-identical hand-written YAML files
maintained via kustomize across management clusters. This chart makes the server
list the single source of truth, and lets us migrate the fleet from muster to
agentgateway by flipping a toggle instead of rewriting every file.

**Who can use it?**

Giant Swarm internal teams running the agentic platform on a management cluster.
Deployed once per management cluster (its server list + namespace come from that
cluster's App CR values).

## Installing

There are several ways to install this app onto a workload cluster.

- [Using GitOps to instantiate the App](https://docs.giantswarm.io/tutorials/continuous-deployment/apps/add-appcr/)
- By creating an [App resource](https://docs.giantswarm.io/reference/platform-api/crd/apps.application.giantswarm.io) using the platform API as explained in [Getting started with App Platform](https://docs.giantswarm.io/tutorials/fleet-management/app-platform/).

## Configuring

### Render toggles

| Value                  | Default | Effect                                                                 |
|------------------------|---------|------------------------------------------------------------------------|
| `muster.enabled`       | `true`  | Render `MCPServer` CRs.                                                 |
| `agentgateway.enabled` | `false` | Render `AgentgatewayBackend` + per-target exchange `AgentgatewayPolicy`. |
| `agentgateway.viaMuster` | `false` | Front muster: render a single backend target → muster's aggregator (`agentgateway.musterUrl`) instead of per-server targets. Requires `muster.enabled: true`. |

Both `muster.enabled` and `agentgateway.enabled` may be `true` during the muster → agentgateway
migration.

### Input contract

The input is **abstract** — it does not mirror any one CRD. There are two pieces:

**`identityProviders`** — a map, defined once and referenced by servers. Multiple MCP servers that
share a cluster's Dex point at the same entry instead of repeating the token-exchange config.

**`mcpServers`** — a flat list. Required per entry: `cluster`, `group`, `url`. Optional: `name`
(defaults to `<cluster>-mcp-<group>`), `namespace` (defaults to the release namespace), `transport`
(default `streamable-http`), `autoStart` (default `true`), `timeout`, `toolPrefix`, and `auth`.

`auth.mode` is the one knob that describes how the server is authenticated, vendor-neutrally:

| `auth.mode` | meaning |
|---|---|
| `none`     | no auth (anonymous upstream) |
| `oauth`    | caller authenticated, no token propagated to the upstream |
| `forward`  | forward the caller's verified token to the upstream (same-cluster only) |
| `exchange` | RFC 8693 token exchange against `auth.provider`'s Dex (cross-cluster) |

```yaml
muster:
  enabled: true
agentgateway:
  enabled: false

identityProviders:
  cluster-b:
    tokenEndpoint: https://dex.cluster-b.example.com/token
    connectorId: giantswarm-simple-oidc
    scopes: openid profile email groups
    credentialsSecret:
      name: cluster-b-token-exchange-credentials
      clientIdKey: client-id
      clientSecretKey: client-secret

mcpServers:
  # same-cluster: forward the caller's verified token
  - cluster: cluster-a
    group: kubernetes
    url: https://mcp-kubernetes.cluster-a.example.com/mcp
    auth: { mode: forward }

  # cross-cluster: token exchange, sharing the "cluster-b" provider
  - cluster: cluster-b
    group: prometheus
    url: https://mcp-prometheus.cluster-b.example.com/mcp
    auth: { mode: exchange, provider: cluster-b }

  # local one-off, anonymous
  - cluster: cluster-a
    group: runbooks
    url: http://mcp-runbooks.mcp-runbooks.svc.cluster.local:8080/mcp
    timeout: 30
    toolPrefix: runbooks
    auth: { mode: none }
```

### muster output (`muster.enabled: true`)

Each `mcpServers` entry becomes one `muster.giantswarm.io/v1alpha1` `MCPServer` in the release
namespace, with the abstract input translated to the muster CRD:

- `metadata.name` ← `name` (or `<cluster>-mcp-<group>`); labels include
  `muster.giantswarm.io/management-cluster: <cluster>` and `muster.giantswarm.io/type: mcp-<group>`.
- `spec.type` ← `transport`; plus `spec.url`, `spec.timeout`, `spec.toolPrefix`, `spec.autoStart`.
- `spec.auth` is built from `auth.mode`: `none`→`type: none`; `oauth`→`type: oauth, forwardToken:
  false`; `forward`→`forwardToken: true`; `exchange`→`tokenExchange{...}` expanded from the
  referenced `identityProviders` entry. `requiredAudiences` defaults to `defaults.audiences` for
  the token-propagating modes.
- `spec.family` is emitted when the entry's `group` is listed under `muster.families` (e.g.
  `kubernetes`, `prometheus`); singleton groups (`pro`, `runbooks`) get none.

muster is itself the MCP client: it makes the outbound connection to each server and handles
HTTPS / OAuth / RFC 8693 token exchange directly. The rendered output is a semantically identical
drop-in for the hand-written `MCPServer` files this chart replaces (verified by diff).

### agentgateway output (`agentgateway.enabled: true`)

The same list renders agentgateway **configuration** (all on OSS agentgateway — no Enterprise
required). The chart owns only per-server config; the `Gateway`, the `HTTPRoute`, and inbound
caller (JWT) validation belong to whoever deploys the agentgateway. **The chart emits no resource
that references a `Gateway`** — everything it produces is either owned outright
(`AgentgatewayBackend`) or attaches to that Backend.

**`AgentgatewayBackend`** — one multiplexed backend; every entry becomes an MCP target:

- `static.host` / `port` / `path` are parsed from `url`; `protocol: StreamableHTTP`.
- `https://` upstreams (e.g. a remote cluster's public MCP route) get `static.policies.tls: {}` so
  agentgateway originates TLS to the backend (system CAs, SNI from host). In-cluster `http://`
  upstreams stay plaintext. Without this, agentgateway would speak plaintext to port 443 and fail.
- `auth.mode: forward` → `static.policies.auth.passthrough: {}` — forwards the verified inbound
  token upstream. Only valid where the upstream trusts that token (i.e. the same cluster).

**`AgentgatewayPolicy`** — one **per `auth.mode: exchange` target**:

- Attaches to the `AgentgatewayBackend` via `targetRefs[].sectionName: <target>` (the only way to
  scope a policy to a single MCP target).
- `backend.extAuth` delegates to the muster token-exchange broker
  (`agentgateway.tokenExchange.broker.*`), passing the target's `cluster` and the referenced
  `identityProviders` entry's `tokenEndpoint` / `connectorId` / `scopes` / secret name via
  `grpc.contextExtensions`.
- The broker runs the RFC 8693 exchange (the same logic muster runs today) against **that remote
  cluster's** Dex and injects the exchanged token on the outbound hop. This per-target scoping is
  what makes remote MCPs work: each remote cluster trusts only its own Dex, so a single
  gateway-wide policy could not serve a multiplexed set of remote clusters.
- The broker is a separate muster component — a prerequisite for the agentgateway exchange path.

`auth.audiences` affects only the muster `MCPServer`; on the agentgateway side, inbound
audience/JWT validation is the deployer's responsibility.

> All agentgateway CR shapes above are validated server-side against the live `agentgateway.dev`
> CRDs on a management cluster (a management cluster).

### Fronting muster (`agentgateway.viaMuster: true`)

By default agentgateway connects to each MCP server directly (one target per `mcpServers` entry,
above). Setting `agentgateway.viaMuster: true` instead points agentgateway at **muster's
aggregator MCP endpoint as a single backend target**, so traffic flows
`client → agentgateway → muster → servers`:

```yaml
muster:
  enabled: true          # muster must be running to be fronted
agentgateway:
  enabled: true
  viaMuster: true
  musterUrl: http://agentic-platform-muster.agentic-platform.svc.cluster.local:8090/mcp
```

- The `AgentgatewayBackend` gets exactly one target (`muster`), parsed from `musterUrl`. An
  `https://` endpoint gets `static.policies.tls: {}`; the verified inbound token is forwarded to
  muster via `static.policies.auth.passthrough`.
- muster keeps doing all of the per-server work — connection, OAuth, RFC 8693 token exchange,
  family aggregation — driven by the same `mcpServers` list (its `MCPServer` CRs are unchanged).
- **No** per-target `AgentgatewayPolicy` and **no** `tokenExchange` broker are rendered in this
  mode: there are no per-server targets to attach them to, and muster owns exchange downstream.
- The win is observability: agentgateway becomes the single MCP choke point, so every tool call is
  visible to the gateway's metrics / traces / access logs. Wiring up that telemetry export
  (OTEL/metrics endpoints) is the agentgateway deployer's responsibility — out of this chart's
  scope, like the `Gateway` / `HTTPRoute` — this chart only provides the topology.

### CRDs

This chart does **not** install CRDs, and does **not** create the agentgateway
`Gateway` or `HTTPRoute`. The `MCPServer` CRD is owned by the muster operator; the
`agentgateway.dev` CRDs and the Gateway/HTTPRoute resources are owned by the
agentgateway / kgateway install. Those must already be present on the cluster.

See our [full reference on how to configure apps](https://docs.giantswarm.io/tutorials/fleet-management/app-platform/app-configuration/) for more details.

## Compatibility

This app has been tested to work with the following workload cluster release versions:

- _add release version_

## Limitations

Some apps have restrictions on how they can be deployed.
Not following these limitations will most likely result in a broken deployment.

- The `MCPServer`, `agentgateway.dev`, and Gateway API CRDs must already be installed
  on the cluster — this chart only renders the custom resources, not their definitions.
- Enabling the agentgateway path for token-exchange servers requires the muster
  token-exchange broker to be deployed.

## Credit

- https://github.com/giantswarm/agentic-platform-mcps
