#!/bin/bash
set -e

# Find unmanaged pods

KUBECTL=${KUBECTL:-"kubectl"}
KUBECTL_FLAGS=${KUBECTL_FLAGS:-""} # possibly use "--all-namespaces"
$KUBECTL get pods $KUBECTL_FLAGS -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name},{.metadata.ownerReferences[0].kind}|{end}' | tr '|' '\n' | grep -E ',$' | sed 's/.$//'
