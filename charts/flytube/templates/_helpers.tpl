{{- define "flytube.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flytube.secretname" -}}
{{- include "flytube.name" . | printf "%s-certificates" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flytube.image" -}}
    {{- $repository := default "infralightio/flytube" .Values.image.repository -}}
    {{- $tag := default "latest" .Values.image.tag -}}
    {{- printf "%s:%s" $repository $tag }}
{{- end }}

{{- define "flytube.imagePullPolicy" -}}
    {{- default "Always" .Values.image.pullPolicy }}
{{- end }}

