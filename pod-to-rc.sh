#!/bin/bash
set -e

# Convert a pod to more permanent solution in a breeze

KUBECTL=${KUBECTL:-"kubectl"}
JQ=${JQ:-"jq"}
# RESOURCE can be rc / rs / deployment

if [ $# -lt 1 ]; then
  echo "Creates replication controller (replica set) json output from existing pod on current kubernetes context or stdin if pod-name is -"
  echo "When removing it, make sure to use $KUBECTL delete ... --cascade=false"
  echo "Usage: $0 [<pod-name>|-]"
  exit 1
fi

BASENAME=$(basename $0)
if [ -z "$RESOURCE" ]; then
  for ONE in rc rs deployment; do
    grep -q $ONE <<< $BASENAME && RESOURCE="$ONE"
  done
fi

POD_NAME="$1"

if [ "$RESOURCE" == "rs" ]; then
  TEMPLATE='{ "apiVersion": "extensions/v1beta1", "kind": "ReplicaSet", "spec": { "replicas": 1 } }'
elif [ "$RESOURCE" == "rc" ]; then
  TEMPLATE='{ "apiVersion": "v1", "kind": "ReplicationController", "spec": { "replicas": 1 } }'
elif [ "$RESOURCE" == "deployment" ]; then
  TEMPLATE='{ "apiVersion": "extensions/v1beta1", "kind": "Deployment", "spec": { "progressDeadlineSeconds": 600, "replicas": 1, "revisionHistoryLimit": 10, "strategy": { "rollingUpdate": { "maxSurge": 1, "maxUnavailable": 1 }, "type": "RollingUpdate" } } }'
else
  echo "Resource $RESOURCE not supported"
  exit 1
fi

DIR=$(mktemp -d)
function finish {
  rm -rf $DIR
}
trap finish EXIT

if [ "$POD_NAME" != "-" ]; then
  $KUBECTL get pod $POD_NAME -o json 2>/dev/null > $DIR/pod.json || true
else
  cat > $DIR/pod.json
fi

if [ ! -s "$DIR/pod.json" ]; then
  if [ "$POD_NAME" != "-" ]; then
    echo "Pod $POD_NAME does not exist"
  else
    echo "You need to pipe something ala \"cat somefile | $0 -\""
  fi
  exit 1
fi

cat $DIR/pod.json | $JQ ' .metadata | del(.annotations["kubectl.kubernetes.io/last-applied-configuration"]) | del(.annotations["kubectl.kubernetes.io/last-applied-configuration"]) | del(.creationTimestamp) | del(.resourceVersion) | del(.selfLink) | del(.uid) | del(.annotations["kubernetes.io/limit-ranger"])' > $DIR/metadata.json || exit 2

# Sanity check to prevent double owners
unset NO_OWNER
cat $DIR/metadata.json | $JQ '.ownerReferences' | grep -q null && NO_OWNER=true

if [ -z "$NO_OWNER" ] && [ -z "$FORCE" ]; then
  echo "Pod ${POD_NAME} already has an owner, you can't create resource unless you do \"FORCE=true\""
  exit 1
fi

cat $DIR/pod.json | $JQ '.spec' > $DIR/spec.json

LABELS=$(cat $DIR/metadata.json | jq '.labels')

# Stick the parts together
if [ "$RESOURCE" == "rs" ]; then
  $JQ ".metadata = $(cat $DIR/metadata.json) | .spec.selector.matchLabels = $(cat $DIR/metadata.json | $JQ '.labels') | .spec.template.metadata = $(cat $DIR/metadata.json) | .spec.template.spec = $(cat $DIR/spec.json)" <<< $TEMPLATE
elif [ "$RESOURCE" == "rc" ]; then
  $JQ ".metadata = $(cat $DIR/metadata.json) | .spec.selector = $(cat $DIR/metadata.json | $JQ '.labels') | .spec.template.metadata = $(cat $DIR/metadata.json) | .spec.template.spec = $(cat $DIR/spec.json)" <<< $TEMPLATE
elif [ "$RESOURCE" == "deployment" ]; then
  $JQ ".metadata = $(cat $DIR/metadata.json) | .spec.selector.matchLabels = $(cat $DIR/metadata.json | $JQ '.labels') | .spec.template.metadata = $(cat $DIR/metadata.json) | .spec.template.spec = $(cat $DIR/spec.json)" <<< $TEMPLATE
fi 

rm -rf $DIR
