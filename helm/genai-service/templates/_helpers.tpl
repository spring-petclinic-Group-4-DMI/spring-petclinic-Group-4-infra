{{- define "genai-service.fullname" -}}
{{- .Release.Name }}-genai-service
{{- end }}
{{- define "genai-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "genai-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "genai-service.selectorLabels" -}}
app.kubernetes.io/name: genai-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
