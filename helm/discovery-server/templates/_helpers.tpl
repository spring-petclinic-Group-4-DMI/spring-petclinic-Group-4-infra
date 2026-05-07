{{- define "discovery-server.fullname" -}}
{{- .Release.Name }}-discovery-server
{{- end }}
{{- define "discovery-server.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "discovery-server.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "discovery-server.selectorLabels" -}}
app.kubernetes.io/name: discovery-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
