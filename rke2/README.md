## Rancher RKE2 installation on-demand

For Rancher on top of RKE2, use [`rancher-rke2`](../rancher-rke2/README.md), which installs both (and is the
one to pick on boxctl.io), or run [`rancher`](../rancher/README.md) on a VM this template set up.

```
onctl up -n rke2 -a rke2/rke2.sh --download /tmp/rke2.yaml
```
This will create the vm, install RKE2 and download the kubeconfig file to you local. Then; 

```
onctl ssh rke2 
```
You can directly ssh to the vm and start using "k" alias to use kubectl 

```
kubectl --kubeconfig rke2.yaml get po -A
```
OR 
```
export KUBECONFIG=$PWD/rke2.yaml
```
to directly set your KUBECONFIG on your local computer.

