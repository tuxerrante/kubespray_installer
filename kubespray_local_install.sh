#!/bin/bash
# ======================================================
#   kubespray first startup on a test machine          =
# ======================================================
#
# Please put your public key on the nodes before running this script
# Then check config vars inside kubespray/inventory/expert
# ======================================================

# Check if SeLinux disabled
SELINUXSTATUS=$(sudo getenforce);
if [ "$SELINUXSTATUS" == "Enforcing" ]; then
    sudo setenforce 0 && sudo sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
    echo "SELINUX set to permissive, please reboot the machine."
    exit 0
fi

# Check firewall status
FWSTATUS=$(sudo systemctl status firewalld >/dev/null);
if [ "$FWSTATUS" == "running" ]; then
    firewall-cmd --permanent --add-port=6443/tcp        # kubelet
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=2379-2380/tcp   # kube-apiserver
    firewall-cmd --permanent --add-port=10251/tcp
    firewall-cmd --permanent --add-port=10252/tcp
    firewall-cmd --permanent --add-port=10255/tcp
    firewall-cmd --permanent --add-port=10257/tcp       # kube-controll
    firewall-cmd --permanent --add-port=10259/tcp       # kube-schedule
    firewall-cmd –-reload
fi


# Useful for ansible administrators
sudo yum install -y python3 python-argcomplete

# Download last code from master branch
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray || exit 1

# Install dependencies from ``requirements.txt``
# sudo yum install -y ansible-2.9.15 python-jinja2 python-netaddr
sudo pip3 install -r requirements.txt

# Copy ``inventory/sample`` as ``inventory/expert_cluster``
cp -rfp ../inventory/expert inventory/

# Add custom users
cp -rfp ../roles/adduser/defaults/main.yml roles/adduser/defaults/main.yml

# Update Ansible inventory file with inventory builder
# declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
my_ip=$(hostname -i)
declare -a IPS="($my_ip)"

# To generate a new YAML inventory uncomment this line
# CONFIG_FILE=inventory/expert/hosts.yaml python3 contrib/inventory_builder/inventory.py "${IPS[@]}"

# Review and change parameters under ``inventory/expert/group_vars``
# cat inventory/expert/group_vars/all/all.yml
# cat inventory/expert/group_vars/k8s-cluster/k8s-cluster.yml

# Enable containerd runtime
if ! sudo systemctl status containerd 1>/dev/null; then 
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum update -y 
    sudo yum install -y containerd.io
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo systemctl enable containerd
fi

# Enable docker
if ! sudo systemctl status docker 1>/dev/null; then 
    sudo yum update -y 
    sudo yum install -y docker
	sudo systemctl restart containerd 
    sudo systemctl enable containerd
fi

## Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
ansible-playbook -i inventory/expert/hosts.yaml --become --become-user=root cluster.yml

# Install and enable k8s dashboard
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.5/aio/deploy/recommended.yaml
sudo kubectl proxy --address='0.0.0.0'

mkdir -p "$HOME/.kube"
sudo cp -f -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
