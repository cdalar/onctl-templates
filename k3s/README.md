## Rancher k3s installation on-demand  

```
 ./onctl up -n qwe -a k3s/k3s-server.sh --download /tmp/k3s.yaml
```
This will create the vm, install k3s and download the kubeconfig file to you local. Then; 

```
kubectl --context k3s.yaml get po -A
```
OR 
```
export KUBECONFIG=$PWD/k3s.yaml
```
to directly set your KUBECONFIG