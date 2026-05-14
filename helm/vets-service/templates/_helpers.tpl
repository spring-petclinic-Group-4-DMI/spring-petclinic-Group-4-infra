{{- define "vets-service.fullname" -}}
{{- .Release.Name }}-vets-service
{{- end }}
{{- define "vets-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "vets-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "vets-service.selectorLabels" -}}
app.kubernetes.io/name: vets-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
