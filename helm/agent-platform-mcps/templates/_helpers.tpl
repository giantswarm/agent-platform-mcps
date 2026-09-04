{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "labels.common" -}}
app: {{ include "name" . | quote }}
{{ include "labels.selector" . }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
application.giantswarm.io/team: {{ index .Chart.Annotations "io.giantswarm.application.team" | quote }}
helm.sh/chart: {{ include "chart" . | quote }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "labels.selector" -}}
app.kubernetes.io/name: {{ include "name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/*
Resolve an mcpServers entry name. Pass the entry as the context.
Defaults to "<cluster>-mcp-<group>" when .name is not set.
*/}}
{{- define "mcp.serverName" -}}
{{- if .name -}}
{{- .name -}}
{{- else -}}
{{- printf "%s-mcp-%s" .cluster .group -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the identity provider referenced by a server's auth.provider, failing
with a clear message if it is missing. Pass a dict {root, server}.
*/}}
{{- define "mcp.provider" -}}
{{- $ref := .server.auth.provider -}}
{{- if not $ref -}}
{{- fail (printf "mcpServers entry %q has auth.mode=exchange but no auth.provider" (include "mcp.serverName" .server)) -}}
{{- end -}}
{{- $p := index .root.Values.identityProviders $ref -}}
{{- if not $p -}}
{{- fail (printf "auth.provider %q (used by %q) is not defined under identityProviders" $ref (include "mcp.serverName" .server)) -}}
{{- end -}}
{{- toYaml $p -}}
{{- end -}}

{{/*
Render spec.auth.authorizationServer for an auth.mode=oauth entry whose
authorization server muster can neither discover nor register with (muster
>= 5.8.0, giantswarm/muster#1144). Mirrors the MCPServer CRD's admission rules
so a bad entry fails at render time, naming the entry, instead of at apply
time. Pass a dict {name, namespace, as}: the rendered server name, the
namespace the MCPServer lands in (the default for the secret reference) and
the entry's auth.authorizationServer block.
*/}}
{{- define "mcp.authorizationServer" -}}
{{- $as := .as -}}
{{- $known := list "issuer" "authorizationEndpoint" "tokenEndpoint" "scopes" "clientCredentialsSecretRef" "grantScope" -}}
{{- range $k, $_ := $as -}}
{{- if not (has $k $known) -}}
{{- fail (printf "mcpServers entry %q: unknown auth.authorizationServer key %q (want one of %s)" $.name $k (join ", " $known)) -}}
{{- end -}}
{{- end -}}
{{- if not $as.issuer -}}
{{- fail (printf "mcpServers entry %q: auth.authorizationServer.issuer is required" .name) -}}
{{- end -}}
{{- if ne (empty $as.authorizationEndpoint) (empty $as.tokenEndpoint) -}}
{{- fail (printf "mcpServers entry %q: auth.authorizationServer.authorizationEndpoint and tokenEndpoint must be set together" .name) -}}
{{- end -}}
{{- if and $as.grantScope (not (has $as.grantScope (list "session" "subject"))) -}}
{{- fail (printf "mcpServers entry %q: auth.authorizationServer.grantScope must be session or subject, got %q" .name $as.grantScope) -}}
{{- end -}}
{{- if and $as.clientCredentialsSecretRef (not $as.clientCredentialsSecretRef.name) -}}
{{- fail (printf "mcpServers entry %q: auth.authorizationServer.clientCredentialsSecretRef.name is required" .name) -}}
{{- end -}}
authorizationServer:
  issuer: {{ $as.issuer }}
  {{- with $as.authorizationEndpoint }}
  authorizationEndpoint: {{ . }}
  {{- end }}
  {{- with $as.tokenEndpoint }}
  tokenEndpoint: {{ . }}
  {{- end }}
  {{- with $as.scopes }}
  scopes: {{ . | quote }}
  {{- end }}
  {{- with $as.clientCredentialsSecretRef }}
  clientCredentialsSecretRef:
    name: {{ .name }}
    namespace: {{ .namespace | default $.namespace }}
    {{- with .clientIdKey }}
    clientIdKey: {{ . }}
    {{- end }}
    {{- with .clientSecretKey }}
    clientSecretKey: {{ . }}
    {{- end }}
  {{- end }}
  {{- with $as.grantScope }}
  grantScope: {{ . }}
  {{- end }}
{{- end -}}

{{/*
URL parsing helpers for agentgateway static targets. Pass the url string as the
context. Examples assume "https://mcp-kubernetes.cluster.example.io/mcp".
*/}}
{{- define "mcp.host" -}}
{{- $noscheme := . | trimPrefix "https://" | trimPrefix "http://" -}}
{{- $noscheme | splitList "/" | first | splitList ":" | first -}}
{{- end -}}

{{- define "mcp.port" -}}
{{- $noscheme := . | trimPrefix "https://" | trimPrefix "http://" -}}
{{- $hostport := $noscheme | splitList "/" | first -}}
{{- $parts := $hostport | splitList ":" -}}
{{- if gt (len $parts) 1 -}}
{{- $parts | last -}}
{{- else if hasPrefix "https://" . -}}
443
{{- else -}}
80
{{- end -}}
{{- end -}}

{{- define "mcp.path" -}}
{{- $noscheme := . | trimPrefix "https://" | trimPrefix "http://" -}}
{{- $rest := $noscheme | splitList "/" | rest -}}
{{- if $rest -}}
/{{ $rest | join "/" }}
{{- else -}}
/
{{- end -}}
{{- end -}}
