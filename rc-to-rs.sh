#!/bin/bash
set -e

# Convert a replication controller (old) to replica set (new)

KUBECTL=${KUBECTL:-"kubectl"}
JQ=${JQ:-"jq"}

if [ $# -lt 1 ]; then
  echo "Convert a replication controller (RC) to replica set (RS)"
  echo "Usage: $0 <rc-name>|- [reparent]"
  exit 1
fi

if [ $# -gt 1 ]; then
  if [ "$1" == "-" ]; then
    echo "Reparenting is not compatible with stdin mode"
    exit 1
  fi
  REPARENT=true
fi

NAME="$1"

DIR=$(mktemp -d)
function finish {
  rm -rf $DIR
}
trap finish EXIT

if [ "$NAME" != "-" ]; then
  $KUBECTL get rc $NAME -o json 2>/dev/null > $DIR/input.json || true
else
  cat > $DIR/input.json
fi

if [ ! -s "$DIR/input.json" ]; then
  if [ "$NAME" != "-" ]; then
    echo "$NAME does not exist"
  else
    echo "You need to pipe something ala \"cat somefile | $0 -\""
  fi
  exit 1
fi

# Actual magic happens here

if [ -z "$REPARENT" ]; then
  cat $DIR/input.json | $JQ '. + {"burek": .spec.selector} | del(.spec.selector) | .spec.selector.matchLabels = .burek | del(.burek) | .apiVersion = "extensions/v1beta1" | .kind = "ReplicaSet"' || exit 2
else
  cat $DIR/input.json | $JQ '. + {"burek": .spec.selector} | del(.spec.selector) | .spec.selector.matchLabels = .burek | del(.burek) | .apiVersion = "extensions/v1beta1" | .kind = "ReplicaSet"' > $DIR/output.json
  $KUBECTL get rc $NAME -o json > $DIR/backup.json
  $KUBECTL delete rc $NAME --cascade=false
  $KUBECTL apply -f $DIR/output.json || $KUBECTL apply -f $DIR/backup.json
fi

rm -rf $DIR
