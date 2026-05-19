{{/*
Service name — taken from image.service in helm-values/{service}.yaml.
Falls back to .Release.Name if unset (for `helm template` smoke tests).
*/}}
{{- define "petclinic.serviceName" -}}
{{- default .Release.Name .Values.image.service -}}
{{- end -}}

{{/*
Full image reference: {registry}/{envPrefix}/{service}:{tag}
*/}}
{{- define "petclinic.image" -}}
{{- $tag := .Values.image.tag | default "latest" -}}
{{- printf "%s/%s/%s:%s" .Values.image.registry .Values.image.envPrefix (include "petclinic.serviceName" .) $tag -}}
{{- end -}}

{{/*
Service port — falls back to containerPort when service.port is 0.
*/}}
{{- define "petclinic.servicePort" -}}
{{- if eq (int .Values.service.port) 0 -}}
{{- .Values.containerPort -}}
{{- else -}}
{{- .Values.service.port -}}
{{- end -}}
{{- end -}}

{{/*
Spring profiles — joined with commas. Adds "mysql" automatically when mysql.enabled.
*/}}
{{- define "petclinic.springProfiles" -}}
{{- $profiles := .Values.springProfiles -}}
{{- if .Values.mysql.enabled -}}
{{- $profiles = append $profiles "mysql" -}}
{{- end -}}
{{- join "," $profiles -}}
{{- end -}}

{{/*
ServiceAccount name — honours .Values.serviceAccount.name then falls back to service name.
*/}}
{{- define "petclinic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "petclinic.serviceName" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Standard labels — applied to every resource the chart produces.
*/}}
{{- define "petclinic.labels" -}}
app.kubernetes.io/name: {{ include "petclinic.serviceName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: petclinic
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
petclinic.io/environment: {{ .Values.global.environment }}
{{- end -}}

{{/*
Selector labels — narrower than the full label set, used by Deployment and Service selectors.
*/}}
{{- define "petclinic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "petclinic.serviceName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Remote secret path in AWS Secrets Manager for the current env.
*/}}
{{- define "petclinic.rdsSecretKey" -}}
{{- printf "petclinic/%s/rds-credentials" .Values.global.environment -}}
{{- end -}}

{{- define "petclinic.openaiSecretKey" -}}
{{- printf "petclinic/%s/openai-api-key" .Values.global.environment -}}
{{- end -}}
