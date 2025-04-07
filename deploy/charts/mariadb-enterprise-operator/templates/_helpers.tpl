{{/*
Expand the name of the chart.
*/}}
{{- define "mariadb-enterprise-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mariadb-enterprise-operator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mariadb-enterprise-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mariadb-enterprise-operator.labels" -}}
helm.sh/chart: {{ include "mariadb-enterprise-operator.chart" . }}
{{ include "mariadb-enterprise-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mariadb-enterprise-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mariadb-enterprise-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Webhook common labels
*/}}
{{- define "mariadb-enterprise-operator-webhook.labels" -}}
helm.sh/chart: {{ include "mariadb-enterprise-operator.chart" . }}
{{ include "mariadb-enterprise-operator-webhook.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Webhook selector labels
*/}}
{{- define "mariadb-enterprise-operator-webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mariadb-enterprise-operator.name" . }}-webhook
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Webhook CA path to use cert-controller issued certificates
*/}}
{{- define "mariadb-enterprise-operator-webhook.certControllerCAPath" -}}
{{ .Values.webhook.cert.ca.path | default "/tmp/k8s-webhook-server/certificate-authority" }}
{{- end }}

{{/*
Webhook CA full path to use cert-controller issued certificates
*/}}
{{- define "mariadb-enterprise-operator-webhook.certControllerFullCAPath" -}}
{{- printf "%s/%s" (include "mariadb-enterprise-operator-webhook.certControllerCAPath" .) (.Values.webhook.cert.ca.key | default "tls.crt") }}
{{- end }}

{{/*
Webhook CA path to use cert-manager issued certificates
*/}}
{{- define "mariadb-enterprise-operator-webhook.certManagerCAPath" -}}
{{ .Values.webhook.cert.ca.path | default .Values.webhook.cert.path }}
{{- end }}

{{/*
Webhook CA full path to use cert-manager issued certificates
*/}}
{{- define "mariadb-enterprise-operator-webhook.certManagerFullCAPath" -}}
{{- printf "%s/%s" (include "mariadb-enterprise-operator-webhook.certManagerCAPath" .) (.Values.webhook.cert.ca.key | default "ca.crt") }}
{{- end }}

{{/*
Cert-controller common labels
*/}}
{{- define "mariadb-enterprise-operator-cert-controller.labels" -}}
helm.sh/chart: {{ include "mariadb-enterprise-operator.chart" . }}
{{ include "mariadb-enterprise-operator-cert-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Cert-controller selector labels
*/}}
{{- define "mariadb-enterprise-operator-cert-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mariadb-enterprise-operator.name" . }}-cert-controller
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mariadb-enterprise-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.enabled }}
{{- default (include "mariadb-enterprise-operator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the webhook service account to use
*/}}
{{- define "mariadb-enterprise-operator-webhook.serviceAccountName" -}}
{{- if .Values.webhook.serviceAccount.enabled }}
{{- default (printf "%s-webhook" (include "mariadb-enterprise-operator.fullname" .))  .Values.webhook.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.webhook.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the cert-controller service account to use
*/}}
{{- define "mariadb-enterprise-operator-cert-controller.serviceAccountName" -}}
{{- if .Values.certController.serviceAccount.enabled }}
{{- default (printf "%s-cert-controller" (include "mariadb-enterprise-operator.fullname" .))  .Values.certController.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.certController.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Util function for generating the image URL based on the provided options.
*/}}
{{- define "image" -}}
  {{- $defaultTag := index . 1 -}}
  {{- with index . 0 -}}
    {{- $repository := .repository | default "" -}}
    {{- $digest := .digest -}}
    {{- $tag := default $defaultTag .tag -}}
    {{- printf "%s" $repository }}
    {{- if $digest -}}
      {{ printf "@%s" $digest }}
    {{- else -}}
      {{ printf ":%s" $tag }}
    {{- end -}}
  {{- end }}
{{- end }}