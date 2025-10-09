{{/*
Expand the name of the chart.
*/}}
{{- define "uds-minio-config.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "uds-minio-config.fullname" -}}
{{- $name := default .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "uds-minio-config.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "uds-minio-config.labels" -}}
helm.sh/chart: {{ include "uds-minio-config.chart" . }}
{{ include "uds-minio-config.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Release.Name | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "uds-minio-config.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds-minio-config.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "uds-minio-config.annotations" -}}
uds.dev/package: "true"
uds.dev/package-version: "{{ .Chart.Version }}"
uds.dev/package-domain: "{{ .Values.domain }}"
uds.dev/package-description: "Trivy Operator for vulnerability scanning and compliance checks in Kubernetes clusters"
uds.dev/package-maintainers: "Defense Unicorns <mitchell.murphy@defenseunicorns.com>"
{{- end }}
