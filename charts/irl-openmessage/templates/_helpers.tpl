{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "irl-openmessage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "irl-openmessage.fullname" -}}
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
Common labels.
*/}}
{{- define "irl-openmessage.labels" -}}
app.kubernetes.io/name: {{ include "irl-openmessage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "irl-openmessage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "irl-openmessage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "irl-openmessage.serviceAccountName" -}}
{{- include "irl-openmessage.fullname" . }}
{{- end }}

{{/*
Image reference. Digest-only on purpose: a tag is mutable and this pod holds
the Google pairing, so "whatever :latest is today" is not an acceptable input.
*/}}
{{- define "irl-openmessage.image" -}}
{{- $digest := required "image.digest is REQUIRED -- pin the ghcr.io/deathnerd/openmessage manifest digest (sha256:...). This chart has no default image and will not render without one." .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository $digest }}
{{- end }}

{{/*
OPENMESSAGES_ALLOWED_HOSTS value: explicit app.allowedHosts when set, else the
single ingress host. Any request arriving with some other Host gets 403 from
the daemon, bearer token or not.
*/}}
{{- define "irl-openmessage.allowedHosts" -}}
{{- if .Values.app.allowedHosts }}
{{- join "," .Values.app.allowedHosts }}
{{- else }}
{{- required "ingress.host is required (or set app.allowedHosts explicitly) -- OPENMESSAGES_ALLOWED_HOSTS cannot be empty or every request 403s" .Values.ingress.host }}
{{- end }}
{{- end }}

{{/*
The first allowed Host. Used for the probe Host header: kubelet dials the POD
IP, so the Host header it sends is "<podIP>:<port>", which is by definition not
in OPENMESSAGES_ALLOWED_HOSTS. If the daemon applies its Host check to /healthz
too, unmodified probes would 403 forever and the pod would never become ready.
Sending the real hostname costs nothing if the check does not apply, and is the
difference between "works" and "permanent crashloop" if it does.
*/}}
{{- define "irl-openmessage.primaryHost" -}}
{{- if .Values.app.allowedHosts }}
{{- first .Values.app.allowedHosts }}
{{- else }}
{{- required "ingress.host is required (or set app.allowedHosts explicitly)" .Values.ingress.host }}
{{- end }}
{{- end }}

{{/*
Absolute path of the mounted control-token file.
*/}}
{{- define "irl-openmessage.tokenFile" -}}
{{- printf "%s/%s" (trimSuffix "/" .Values.secret.mountPath) .Values.secret.key }}
{{- end }}

{{/*
Name of the ipAllowList middleware.
*/}}
{{- define "irl-openmessage.allowListMiddleware" -}}
{{- printf "%s-ip-allowlist" (include "irl-openmessage.fullname" .) }}
{{- end }}
