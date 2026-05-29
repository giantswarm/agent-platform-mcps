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