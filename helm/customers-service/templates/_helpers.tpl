{{- define "customers-service.fullname" -}}
{{- .Release.Name }}-customers-service
{{- end }}
{{- define "customers-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "customers-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "customers-service.selectorLabels" -}}
app.kubernetes.io/name: customers-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
