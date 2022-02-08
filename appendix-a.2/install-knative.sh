#!/usr/bin/env bash
 
set -o nounset 
set -o pipefail
set -o errexit
 
serving_version='v1.2.0'
eventing_version='v1.2.0'
kourier_version='v1.2.0'
app_name="knative-$serving_version"
 
# Deploy
kapp deploy \
--app $app_name \
--yes \
 
--file "https://github.com/knative/serving/releases/download/$serving_version/serving-crds.yaml" \
--file "https://github.com/knative/serving/releases/download/$serving_version/serving-core.yaml" \
--file "https://github.com/knative/net-kourier/releases/download/$kourier_version/kourier.yaml" \
--file "https://github.com/knative/eventing/releases/download/$eventing_version/eventing.yaml"

# Update domain
kapp deploy \
--app $app_name \
--yes \
--patch \ 
--file <(ytt --file code/domain-config-map.yaml-file code/values.yaml —data-value-yaml ip_address=(kubectl --namespace kourier-system  get service kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}' ))  