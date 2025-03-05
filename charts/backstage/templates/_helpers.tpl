{{/*
Returns custom hostname
*/}}
{{- define "janus-idp.hostname" -}}
    {{- if .Values.global.host -}}
        {{- .Values.global.host -}}
    {{- else if .Values.global.clusterRouterBase -}}
        {{- printf "%s-%s.%s" (include "common.names.fullname" .) .Release.Namespace .Values.global.clusterRouterBase -}}
    {{- else -}}
        {{ fail "Unable to generate hostname" }}
    {{- end -}}
{{- end -}}

{{/*
Returns a secret name for service to service auth
*/}}
{{- define "janus-idp.backend-secret-name" -}}
    {{- if .Values.global.auth.backend.existingSecret -}}
        {{- .Values.global.auth.backend.existingSecret -}}
    {{- else -}}
        {{- printf "%s-auth" .Release.Name -}}
    {{- end -}}
{{- end -}}

{{/*
Sets the secretKeyRef name for Backstage to the PostgreSQL existing secret if it present
*/}}
{{- define "janus-idp.postgresql.secretName" -}}
    {{- if ((((.Values).global).postgresql).auth).existingSecret -}}
        {{- .Values.global.postgresql.auth.existingSecret -}}
    {{- else if .Values.postgresql.auth.existingSecret -}}
        {{- .Values.postgresql.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s-%s" .Release.Name "postgresql" -}}
    {{- end -}}
{{- end -}}

{{/*
Get the password secret.
Referenced from: https://github.com/bitnami/charts/blob/main/bitnami/postgresql/templates/_helpers.tpl#L94-L105
*/}}
{{- define "postgresql.v1.secretName" -}}
    {{- if .Values.global.postgresql.auth.existingSecret -}}
        {{- printf "%s" (tpl .Values.global.postgresql.auth.existingSecret $) -}}
    {{- else if .Values.auth.existingSecret -}}
        {{- printf "%s" (tpl .Values.auth.existingSecret $) -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/* Helepr functions */}}

{{- define "unmanaged-resource-exists" -}}
    {{- $api := index . 0 -}}
    {{- $kind := index . 1 -}}
    {{- $namespace := index . 2 -}}
    {{- $name := index . 3 -}}
    {{- $releaseName := index . 4 -}}
    {{- $apiCapabilities := index . 5 -}}
    {{- $unmanagedSubscriptionExists := "true" -}}
    {{- if $apiCapabilities.Has (printf "%s/%s" $api $kind) }}
        {{- $existingOperator := lookup $api $kind $namespace $name -}}
        {{- if empty $existingOperator -}}
            {{- "false" -}}
        {{- else -}}
            {{- $isManagedResource := include "is-managed-resource" (list $existingOperator $releaseName) -}}
            {{- if eq $isManagedResource "true" -}}
                {{- "false" -}}
            {{- else -}}
                {{- "true" -}}
            {{- end -}}
        {{- end -}}
    {{- else -}}
        {{- "false" -}}
    {{- end -}}
{{- end -}}

{{- define "is-managed-resource" -}}
    {{- $resource := index . 0 -}}
    {{- $releaseName := index . 1 -}}
    {{- $resourceReleaseName := dig "metadata" "annotations" (dict "meta.helm.sh/release-name" "NA") $resource -}}
    {{- if eq (get $resourceReleaseName "meta.helm.sh/release-name") $releaseName -}}
        {{- "true" -}}
    {{- else -}}
        {{- "false" -}}
    {{- end -}}
{{- end -}}


{{- define "cluster.domain" -}}
    {{- if .Capabilities.APIVersions.Has "config.openshift.io/v1/Ingress" -}}
        {{- $cluster := (lookup "config.openshift.io/v1" "Ingress" "" "cluster") -}}
        {{- if and (hasKey $cluster "spec") (hasKey $cluster.spec "domain") -}}
            {{- printf "%s" $cluster.spec.domain -}}
        {{- else -}}
            {{ fail "Unable to obtain cluster domain, OCP Ingress Resource is missing the `spec.domain` field." }}
        {{- end }}
    {{- else -}}
        {{ fail "Unable to obtain cluster domain, config.openshift.io/v1/Ingress is missing" }}
    {{- end -}}
{{- end -}}


{{- define "install-tekton-task" -}}
  {{- if and (and (and .Values.orchestrator.tekton.enabled .Values.orchestrator.argocd.enabled) (ne .Values.orchestrator.rhdhOperator.secretRef.k8s.clusterToken "")) (.Capabilities.APIVersions.Has "tekton.dev/v1/Task") }}
        {{- "true" -}}
    {{- else }}
        {{- "false" -}}
    {{- end -}}
{{- end -}}

{{- define "install-tekton-pipeline" -}}
  {{- if and (and (and .Values.orchestrator.tekton.enabled .Values.orchestrator.argocd.enabled) (ne .Values.orchestrator.rhdhOperator.secretRef.k8s.clusterToken "")) (.Capabilities.APIVersions.Has "tekton.dev/v1/Pipeline") }}
        {{- "true" -}}
    {{- else }}
        {{- "false" -}}
    {{- end -}}
{{- end -}}

{{- define "install-argocd-project" -}}
    {{- if and (.Values.orchestrator.argocd.enabled) (.Capabilities.APIVersions.Has "argoproj.io/v1alpha1/AppProject") }}
        {{- "true" -}}
    {{- else }}
        {{- "false" -}}
    {{- end -}}
{{- end -}}


{{- define "get-namespace-with-label" -}}
    {{- $paramValue:= index . 0 -}}
    {{- $matchingLabel:= index . 1 -}}
    {{- if $paramValue -}}
        {{- $paramValue -}}
    {{- else -}}
        {{- $ns:= "" }}
        {{- $list:= lookup "v1" "Namespace" "" "" -}}
        {{- if eq 0 (len (dig "items" (dict "" "") $list ) )}}
            {{- fail (printf "No namespaces found: %d" (len (dig "items" (dict "" "") $list))  ) }}
        {{- end -}}
        {{- range (dig "items" (dict "" "") $list) }}
            {{- $labels:= dig "metadata" "labels" (dict "" "" ) .  -}}
            {{- if (hasKey $labels $matchingLabel ) }}
                {{- if not $ns }}
                    {{- $ns = dig "metadata" "name" "" . -}}
                {{- else -}}
                    {{- fail (printf "More than one namespace found with label %s: %s and %s" $matchingLabel $ns (dig "metadata" "name" "" .) )}}
                {{- end }}
            {{- end -}}
        {{- end -}}
        {{- if not $ns -}}
            {{- fail (printf "No namespace found with label '%s'. Please follow the installation instructions to properly configure the environment" $matchingLabel) -}}
        {{- end }}
        {{- $ns }}
    {{- end -}}
{{- end -}}

{{- define "get-workflow-namespace" -}}
    {{- if (not (hasKey . "workflowNamespace" ) ) -}}
        {{- $workflowNamespace := include "get-namespace-with-label" (list .Values.orchestrator.orchestrator.namespace "rhdh.redhat.com/workflow-namespace")  }}
        {{- $_ := set . "workflowNamespace" $workflowNamespace }}
    {{- end -}}
    {{- .workflowNamespace -}}
{{- end -}}

{{- define "get-argocd-namespace" -}}
    {{- if .Values.orchestrator.argocd.enabled }}
        {{- if (not (hasKey . "argoCDNamespace" ) ) -}}
            {{- $argoCDNamespace := include "get-namespace-with-label" (list .Values.orchestrator.argocd.namespace "rhdh.redhat.com/argocd-namespace")  }}
            {{- $_ := set . "argoCDNamespace" $argoCDNamespace }}
        {{- end -}}
        {{- .argoCDNamespace -}}
    {{- end -}}
{{- end -}}

{{- define "get-cluster-version" -}}
  {{- $v := "" }}
  {{- $version :=(lookup "config.openshift.io/v1" "ClusterVersion" "" "version") }}
  {{- range $version.status.history }}
    {{- if eq .state "Completed" }}
      {{- $v = (semver .version) }}
    {{- end }}
  {{- end }}

  {{- $validMinors := list "4.13" "4.14" "4.15" "4.16" -}}
  {{- $versionString := printf "%d.%d" $v.Major $v.Minor -}}
  {{- if not (semverCompare ">=4.13 <=4.16" $versionString) -}}
    {{- fail (printf "Unsupported OCP version: %s. Supported versions: %s." $versionString $validMinors) -}}
  {{- end -}}
  {{- $versionString -}}
{{- end -}}

{{- define "get-tekton-version" -}}
        {{- $pipelinesSubs := lookup "operators.coreos.com/v1alpha1" "Subscription" "openshift-operators" "openshift-pipelines-operator-rh" -}}
        {{- $pipelineInstalledVersion := $pipelinesSubs.status.installedCSV}}
        {{- $pipelineVersion := substr 33 ( len $pipelineInstalledVersion) $pipelineInstalledVersion}}
        {{- $pipelineVersion = semver $pipelineVersion }}
        {{- $pipelineVersionString := printf "%d.%d" $pipelineVersion.Major $pipelineVersion.Minor -}}
        {{- $pipelineVersionString -}}
{{- end -}}