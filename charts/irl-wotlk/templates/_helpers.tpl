{{/* vim: set filetype=mustache: */}}

{{- define "irl-wotlk.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "irl-wotlk.fullname" -}}
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

{{- define "irl-wotlk.labels" -}}
app.kubernetes.io/name: {{ include "irl-wotlk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "irl-wotlk.selectorLabels" -}}
app.kubernetes.io/name: {{ include "irl-wotlk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* MySQL service hostname, shared by every AC_*_DATABASE_INFO string. */}}
{{- define "irl-wotlk.mysqlHost" -}}
{{ include "irl-wotlk.fullname" . }}-mysql
{{- end }}

{{/*
Env block shared by dbimport/authserver/worldserver. MYSQL_ROOT_PASSWORD is
pulled from the Secret first so the $(MYSQL_ROOT_PASSWORD) references below
expand (k8s expands $(VAR) against earlier entries in the same list).
*/}}
{{- define "irl-wotlk.dbEnv" -}}
- name: MYSQL_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mysql.existingSecret }}
      key: MYSQL_ROOT_PASSWORD
- name: AC_LOGIN_DATABASE_INFO
  value: "{{ include "irl-wotlk.mysqlHost" . }};3306;root;$(MYSQL_ROOT_PASSWORD);acore_auth"
- name: AC_WORLD_DATABASE_INFO
  value: "{{ include "irl-wotlk.mysqlHost" . }};3306;root;$(MYSQL_ROOT_PASSWORD);acore_world"
- name: AC_CHARACTER_DATABASE_INFO
  value: "{{ include "irl-wotlk.mysqlHost" . }};3306;root;$(MYSQL_ROOT_PASSWORD);acore_characters"
- name: AC_PLAYERBOTS_DATABASE_INFO
  value: "{{ include "irl-wotlk.mysqlHost" . }};3306;root;$(MYSQL_ROOT_PASSWORD);acore_playerbots"
- name: AC_DATA_DIR
  value: "/azerothcore/env/dist/data"
- name: AC_LOGS_DIR
  value: "/azerothcore/env/dist/logs"
{{- end }}

{{/* Shell one-liner: block until MySQL answers and acore_auth.realmlist exists. */}}
{{- define "irl-wotlk.waitForAuthDb" -}}
until mysql -h {{ include "irl-wotlk.mysqlHost" . }} -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT 1 FROM acore_auth.realmlist LIMIT 1" >/dev/null 2>&1; do echo "waiting for acore_auth..."; sleep 10; done
{{- end }}
