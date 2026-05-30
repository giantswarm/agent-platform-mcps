# agentic-platform-mcps

Chart to deploy MCPs for GiantSwarm Agentic Platform.

**Homepage:** <https://github.com/giantswarm/agentic-platform-mcps>

## Source Code

* <https://github.com/giantswarm/agentic-platform-mcps>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| muster.enabled | bool | `true` |  |
| muster.families.kubernetes.instanceArg | string | `"management_cluster"` |  |
| muster.families.prometheus.instanceArg | string | `"management_cluster"` |  |
| agentgateway.enabled | bool | `false` |  |
| agentgateway.viaMuster | bool | `false` |  |
| agentgateway.musterUrl | string | `""` |  |
| agentgateway.host | string | `""` |  |
| agentgateway.musterHost | string | `""` |  |
| agentgateway.gateway.name | string | `"agentgateway"` |  |
| agentgateway.ingressGateway.name | string | `"giantswarm-default"` |  |
| agentgateway.ingressGateway.namespace | string | `"envoy-gateway-system"` |  |
| agentgateway.oauthMode | string | `"validate"` |  |
| agentgateway.jwt.issuer | string | `""` |  |
| agentgateway.jwt.jwksBackendRef.name | string | `"dex"` |  |
| agentgateway.jwt.jwksBackendRef.namespace | string | `"giantswarm"` |  |
| agentgateway.jwt.jwksBackendRef.port | int | `5556` |  |
| agentgateway.jwt.jwksPath | string | `"/keys"` |  |
| agentgateway.jwt.audiences[0] | string | `"dex-k8s-authenticator"` |  |
| agentgateway.tokenExchange.broker.kind | string | `"Service"` |  |
| agentgateway.tokenExchange.broker.name | string | `"muster-token-exchange-broker"` |  |
| agentgateway.tokenExchange.broker.namespace | string | `"muster"` |  |
| agentgateway.tokenExchange.broker.port | int | `8080` |  |
| agentgateway.tokenExchange.broker.protocol | string | `"grpc"` |  |
| defaults.autoStart | bool | `true` |  |
| defaults.transport | string | `"streamable-http"` |  |
| defaults.audiences[0] | string | `"dex-k8s-authenticator"` |  |
| identityProviders | object | `{}` |  |
| mcpServers | list | `[]` |  |
