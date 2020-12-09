#!/bin/bash
echo " This script will destroy the entire cluster: pods, local data, node, master configs.."

read -r -p " Are you really sure [y/n]? " answer
if [[ $answer != "y" ]];then
    exit 0
fi
read -r -p " ARE YOU REALLY SURE [y/n]?? " answer
if [[ $answer != "y" ]];then
    exit 0
fi

kubectl cordon node1
kubectl delete "$(kubectl get pods --all-namespaces)"
kubectl drain --delete-local-data --ignore-daemonsets node1

sudo /usr/local/bin/kubeadm reset
kubectl delete nodes node1

systemctl stop kubelet
systemctl disable kubelet


# Firewall reset

# userdel ...

kubectl cluster-info
echo "Please restart.."