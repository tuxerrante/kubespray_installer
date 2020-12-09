## Customizations

Enabled:
- inventory/expert/group_vars/k8s-cluster/addons.yml
	- dashboard
	- helm

Changed:
- inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
	- cluster_name
	- container_manager: containerd
	- k8s_image_pull_policy: IfNotPresent
	- kubeconfig_localhost: true
	- kubectl_localhost: true

- inventory\expert\inventory.ini

Added:
- delivery-reader in roles/adduser/defaults

TODO:
- delivery-deployer user
- Roles and RolesBinding for delivery users to delivery namespace
- Deploy and configure linkerd


## Test 
```SH
$ kubectl apply -f https://k8s.io/examples/application/shell-demo.yaml  
$ kubectl exec --stdin --tty shell-demo -- /bin/bash  
$$ apt update -y && apt install -y tcpdump lsof procps  
$$ echo "HELLO EXPERT" > /usr/share/nginx/html/index.html  
$$ exit  
$ curl http://localhost  
```

## REMOVE EVERYTHING
`ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root  remove-node.yml`  

```bash
kubectl cordon node1
kubectl delete pod ...
kubectl drain --delete-local-data --ignore-daemonsets node1
kubectl delete nodes node1
systemctl stop kubelet
systemctl disable kubelet
```