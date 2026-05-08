{{- define "config-server.fullname" -}}
{{- .Release.Name }}-config-server
{{- end }}
{{- define "config-server.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "config-server.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "config-server.selectorLabels" -}}
app.kubernetes.io/name: config-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
