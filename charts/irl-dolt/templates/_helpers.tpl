{{/* vim: set filetype=mustache: */}}

{{- define "irl-dolt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "irl-dolt.fullname" -}}
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

{{- define "irl-dolt.labels" -}}
app.kubernetes.io/name: {{ include "irl-dolt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "irl-dolt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "irl-dolt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Labels that select the SERVER pod and nothing else. The provisioning, backup
and test pods carry the plain selectorLabels plus their own component, so no
Service or NetworkPolicy aimed at the server ever matches them.
*/}}
{{- define "irl-dolt.serverSelectorLabels" -}}
{{ include "irl-dolt.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end }}

{{- define "irl-dolt.image" -}}
{{ .Values.image.repository }}:{{ default .Chart.AppVersion .Values.image.tag }}
{{- end }}

{{- define "irl-dolt.secretName" -}}
{{- default (printf "%s-credentials" (include "irl-dolt.fullname" .)) .Values.auth.existingSecret }}
{{- end }}

{{- define "irl-dolt.backupClaim" -}}
{{- default (printf "%s-backup" (include "irl-dolt.fullname" .)) .Values.backup.persistence.existingClaim }}
{{- end }}

{{/* Secret key carrying a user's password. Call with the user dict. */}}
{{- define "irl-dolt.userPasswordKey" -}}
{{- default (printf "%s-password" .name) .passwordKey }}
{{- end }}

{{/*
config.yaml for `dolt sql-server --config`. User-supplied `config` is the
base; the keys the chart depends on are merged over it so they cannot drift
from the Service, the volume mount or the metrics port.
*/}}
{{- define "irl-dolt.config" -}}
{{- $forced := dict
      "data_dir" "/var/lib/dolt"
      "cfg_dir" "/var/lib/dolt/.doltcfg"
      "privilege_file" "/var/lib/dolt/.doltcfg/privileges.db"
      "branch_control_file" "/var/lib/dolt/.doltcfg/branch_control.db"
      "listener" (dict "host" "0.0.0.0" "port" 3306) }}
{{- if .Values.metrics.enabled }}
{{- $_ := set $forced "metrics" (dict "host" "0.0.0.0" "port" (int .Values.metrics.port) "labels" .Values.metrics.labels) }}
{{- end }}
{{- toYaml (mustMergeOverwrite (deepCopy .Values.config) $forced) }}
{{- end }}

{{/*
Fail the render on names that would need quoting gymnastics in SQL or shell.
Deliberately narrow: an instance that needs an exotic name can create it over
SQL; the declared lists stay boring.
*/}}
{{- define "irl-dolt.validate" -}}
{{- range .Values.databases }}
{{- if not (regexMatch "^[A-Za-z0-9_]+$" (toString .name)) }}
{{- fail (printf "databases[].name %q: only letters, digits and underscore are allowed" (toString .name)) }}
{{- end }}
{{- if and .restoreFrom (or (contains "'" .restoreFrom) (contains "\\" .restoreFrom)) }}
{{- fail (printf "databases[%s].restoreFrom must not contain a single quote or a backslash" .name) }}
{{- end }}
{{- end }}
{{- range .Values.users }}
{{- if not (regexMatch "^[A-Za-z0-9_]+$" (toString .name)) }}
{{- fail (printf "users[].name %q: only letters, digits and underscore are allowed" (toString .name)) }}
{{- end }}
{{- if eq (toString .name) "root" }}
{{- fail "users[]: root is managed through auth.*, not the users list" }}
{{- end }}
{{- if not (regexMatch "^[A-Za-z0-9_.%:-]+$" (default "%" .host)) }}
{{- fail (printf "users[%s].host %q: unsupported characters" .name .host) }}
{{- end }}
{{- range .grants }}
{{- if or (contains ";" .) (contains "__DOLT_PW_" .) }}
{{- fail (printf "users[].grants entry %q: must be a single privilege clause" .) }}
{{- end }}
{{- end }}
{{- end }}
{{- if or (contains "'" .Values.backup.urlTemplate) (contains "\\" .Values.backup.urlTemplate) }}
{{- fail "backup.urlTemplate must not contain a single quote or a backslash" }}
{{- end }}
{{- if and .Values.service.external.enabled (not .Values.service.external.nodePort) }}
{{- fail "service.external.nodePort is required when service.external.enabled" }}
{{- end }}
{{- end }}

{{/* Environment shared by every container that talks to the server as root. */}}
{{- define "irl-dolt.clientEnv" -}}
- name: HOME
  value: /tmp
- name: DOLT_HOST
  value: {{ include "irl-dolt.fullname" . }}
- name: DOLT_PORT
  value: {{ .Values.service.port | quote }}
- name: DOLT_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "irl-dolt.secretName" . }}
      key: {{ .Values.auth.rootPasswordKey }}
{{- end }}

{{/* The query every probe runs, through the server, over loopback. */}}
{{- define "irl-dolt.probeExec" -}}
exec:
  command:
    - bash
    - -c
    - exec dolt --host 127.0.0.1 --port 3306 --no-tls -u root -p "$DOLT_ROOT_PASSWORD" sql -q "select 1" >/dev/null
{{- end }}
