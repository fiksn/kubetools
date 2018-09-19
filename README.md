# kubetools
A collection of simple shell scripts to help with Kubernetes and make your life easier

## Tools

* [pod-to-rc.sh](./pod-to-rc.sh) - Convert an existing (unmanaged) pod to a replication-controller
* [pod-to-rs.sh](./pod-to-rs.sh) - Convert an existing (unmanaged) pod to a replicaset
* [pod-to-deployment.sh](./pod-to-deployment.sh) - Convert an existing (unmanaged) pod to a deployment

Basically this is the same shell script that determines by its own name what the conversion destination should be.
Example usage:

```
./pod-to-rc.sh my-pod | kubectl apply -f -
```
```
FORCE=true ./pod-to-rc.sh managed-pod
```
```
cat my-pod | ./pod-to-rc.sh - > rc.json
```

* [rc-to-rs.sh](./rc-to-rs.sh) - Convert a replication-controller to a replicaset resource

Example usage:

```
cat rc.json | ./rc-to-rs.sh - > rs.json
```
```
./rc-to-rs.sh k8s-resource > rc.json
```
```
./rc-to-rs.sh k8s-resource 1
```
(this last example automatically reparents pod from RC to RS)

* [rs-to-rc.sh](./rs-to-rc.sh) - Convert a replicaset to a replication-controller resource.

Is the exact opposite of the previous tool. You usually don't need to go into this direction but can undo the last previous 
command with:

```
./rs-to-rc.sh k8s-resource 1
```

* find-unamanged-pods.sh - list all pods that don't have a source (owner reference)

## Interesting third-party tools

* [kubectx](https://github.com/ahmetb/kubectx) - Allows you to switch context or namespace easily
* [kube-ps1](https://github.com/jonmosco/kube-ps1) - Change your shell prompt to now which k8s cluster you are connected to
