{{- define "fpc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fpc.secretname" -}}
{{- include "fpc.name" . | printf "%s-certificates" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fpc.image" -}}
    {{- $repository := default "infralightio/flytube" .Values.image.repository -}}
    {{- $tag := default "latest" .Values.image.tag -}}
    {{- printf "%s:%s" $repository $tag }}
{{- end }}

{{- define "fpc.imagePullPolicy" -}}
    {{- default "Always" .Values.image.pullPolicy }}
{{- end }}

