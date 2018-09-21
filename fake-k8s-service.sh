#!/bin/bash

### Generate a fake kubernetes service

export KUBECTL=${KUBECTL:-"kubectl"}

function k8s_generate() {
cat << EOF
---
apiVersion: v1
kind: Endpoints
metadata:
  name: $NAME
subsets:
- addresses:
$(for i in $IPS; do echo "  - ip: $i"; done)
  ports:
  - port: $DSTPORT
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: $NAME
spec:
  ports:
  - port: $SRCPORT
    protocol: TCP
    targetPort: $DSTPORT
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
---
EOF
}

function k8s_apply() {
  if [ $PARAMS -eq "4" ]; then 
    k8s_generate | $KUBECTL apply -f -
  else
    $KUBECTL delete service $NAME 2>/dev/null
    $KUBECTL delete ep $NAME 2>/dev/null
  fi
}

function k8s_invoke() {
  if [ $# -ne 4 ] && [ $# -ne 1 ]; then
    return 1 
  fi
  export NAME=$1
  export SRCPORT=$2
  export DSTPORT=$4
  export IPS=$(echo $3 | tr ',' ' ')

  export PARAMS="$#"

  k8s_apply 
}

return 2>/dev/null

if [ $# -ne 4 ] && [ $# -ne 1 ]; then
  echo "Usage: $0 <name> [<source_port> <ips> <destination_port>]"
  echo "Examples:"
  echo -e "\t$0 fake-mysql 3306 10.27.26.116 3306"
  echo -e "\twill create a new service"
  echo -e "\t$0 fake-mysql"
  echo -e "\twill remove the service by name"
  echo -e "\tkubectl get svc | grep fake"
  echo -e "\tto list all fakes"
  exit 1
fi

export NAME=$1
export SRCPORT=$2
export DSTPORT=$4
export IPS=$(echo $3 | tr ',' ' ')

export PARAMS="$#"

if { >&3; } 2> /dev/null; then
 k8s_generate >&3
else
 k8s_apply
fi

