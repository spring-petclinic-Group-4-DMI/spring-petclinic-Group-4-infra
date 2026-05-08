{{- define "api-gateway.fullname" -}}
{{- .Release.Name }}-api-gateway
{{- end }}
{{- define "api-gateway.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "api-gateway.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "api-gateway.selectorLabels" -}}
app.kubernetes.io/name: api-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
