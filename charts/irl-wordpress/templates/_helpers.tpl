{{/* vim: set filetype=mustache: */}}

{{- define "irl-wordpress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "irl-wordpress.fullname" -}}
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

{{- define "irl-wordpress.labels" -}}
app.kubernetes.io/name: {{ include "irl-wordpress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "irl-wordpress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "irl-wordpress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* MariaDB service hostname, shared by the app and the wait-for-db init. */}}
{{- define "irl-wordpress.mariadbHost" -}}
{{ include "irl-wordpress.fullname" . }}-mariadb
{{- end }}

{{/*
PHP appended to the generated wp-config.php. The image eval()s
WORDPRESS_CONFIG_EXTRA on every request, so unlike the salts this block is
live: edit values, upgrade, done.
*/}}
{{- define "irl-wordpress.configExtra" -}}
define( 'WP_HOME', '{{ required "wordpress.siteUrl is required" .Values.wordpress.siteUrl }}' );
define( 'WP_SITEURL', '{{ .Values.wordpress.siteUrl }}' );
define( 'FORCE_SSL_ADMIN', {{ if hasPrefix "https://" .Values.wordpress.siteUrl }}true{{ else }}false{{ end }} );
{{- if .Values.wordpress.disallowFileEdit }}
define( 'DISALLOW_FILE_EDIT', true );
{{- end }}
define( 'WP_AUTO_UPDATE_CORE', {{ if eq (toString .Values.wordpress.autoUpdateCore) "false" }}false{{ else }}'{{ .Values.wordpress.autoUpdateCore }}'{{ end }} );
{{- with .Values.wordpress.configExtra }}
{{ . }}
{{- end }}
{{- end }}

{{/* Shell one-liner: block until MariaDB answers on the wire. */}}
{{- define "irl-wordpress.waitForDb" -}}
until mariadb-admin ping -h {{ include "irl-wordpress.mariadbHost" . }} -u{{ .Values.mariadb.user }} -p"$MARIADB_PASSWORD" --silent; do echo "waiting for mariadb..."; sleep 5; done
{{- end }}
