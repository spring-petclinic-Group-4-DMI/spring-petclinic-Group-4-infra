{{- define "admin-server.fullname" -}}
{{- .Release.Name }}-admin-server
{{- end }}
{{- define "admin-server.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "admin-server.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "admin-server.selectorLabels" -}}
app.kubernetes.io/name: admin-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
