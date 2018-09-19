#!/bin/bash
set -e

# Convert a replica set (new) to replication controller (old)

KUBECTL=${KUBECTL:-"kubectl"}
JQ=${JQ:-"jq"}

if [ $# -lt 1 ]; then
  echo "Convert a replica set (RS) to replication controller (RC)"
  echo "Usage: $0 <rs-name>|- [reparent]"
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
  $KUBECTL get rs $NAME -o json 2>/dev/null > $DIR/input.json || true
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
  cat $DIR/input.json | $JQ '. + {"burek": .spec.selector.matchLabels} | del(.spec.selector.matchLabels) | .spec.selector = .burek | del(.burek) | .apiVersion = "v1" | .kind = "ReplicationController"' || exit 2
else
  cat $DIR/input.json | $JQ '. + {"burek": .spec.selector.matchLabels} | del(.spec.selector.matchLabels) | .spec.selector = .burek | del(.burek) | .apiVersion = "v1" | .kind = "ReplicationController"' > $DIR/output.json
  $KUBECTL get rs $NAME -o json > $DIR/backup.json
  $KUBECTL delete rs $NAME --cascade=false
  $KUBECTL apply -f $DIR/output.json || $KUBECTL apply -f $DIR/backup.json
fi

rm -rf $DIR
