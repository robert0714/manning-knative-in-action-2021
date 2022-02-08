#!/usr/bin/env bash
ytt \
--file values.yaml \
--file domain-config-map.yaml \
--data-value-yaml ip_address=$(kubectl --namespace kourier-system  get service kourier -o  jsonpath='{.status.loadBalancer.ingress[0].ip}') 