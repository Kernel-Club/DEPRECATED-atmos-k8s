{{/* Resource names: <release>-backend etc. Release "atmos" gives atmos-backend. */}}
{{- define "atmos.fullname" -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- end }}

{{- define "atmos.labels" -}}
app.kubernetes.io/name: atmos
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
environment: {{ .Values.environment }}
{{- end }}

{{/* Selector labels for a component: pass (dict "ctx" . "component" "backend") */}}
{{- define "atmos.selectorLabels" -}}
app.kubernetes.io/name: atmos
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "atmos.componentLabels" -}}
{{ include "atmos.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "atmos.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/* Fails the render if an image repository or tag was not passed. pass (dict "name" "backend" "image" .Values.backend.image) */}}
{{- define "atmos.image" -}}
{{- $repository := required (printf "%s.image.repository is required" .name) .image.repository -}}
{{- $tag := required (printf "%s.image.tag is required" .name) .image.tag -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end }}
