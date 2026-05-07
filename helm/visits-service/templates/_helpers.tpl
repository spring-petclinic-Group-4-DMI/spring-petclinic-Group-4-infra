{{- define "visits-service.fullname" -}}
{{- .Release.Name }}-visits-service
{{- end }}
{{- define "visits-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "visits-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "visits-service.selectorLabels" -}}
app.kubernetes.io/name: visits-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
