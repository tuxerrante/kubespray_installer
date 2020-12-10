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

# Check firewall status and add rules
FWSTATUS=$(sudo firewall-cmd --state);
if [ "$FWSTATUS" == "running" ]; then
    sudo firewall-cmd --permanent --add-port=6443/tcp        # kubelet
    sudo firewall-cmd --permanent --add-port=10250/tcp
    sudo firewall-cmd --permanent --add-port=2379-2380/tcp   # kube-apiserver
    sudo firewall-cmd --permanent --add-port=10251/tcp
    sudo firewall-cmd --permanent --add-port=10252/tcp
    sudo firewall-cmd --permanent --add-port=10255/tcp
    sudo firewall-cmd --permanent --add-port=10257/tcp       # kube-controll
    sudo firewall-cmd --permanent --add-port=10259/tcp       # kube-schedule
    sudo firewall-cmd --reload
else
    sudo yum install firewalld
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    sudo firewall-cmd --permanent --add-port=6443/tcp        # kubelet
    sudo firewall-cmd --permanent --add-port=10250/tcp
    sudo firewall-cmd --permanent --add-port=2379-2380/tcp   # kube-apiserver
    sudo firewall-cmd --permanent --add-port=10251/tcp
    sudo firewall-cmd --permanent --add-port=10252/tcp
    sudo firewall-cmd --permanent --add-port=10255/tcp
    sudo firewall-cmd --permanent --add-port=10257/tcp       # kube-controll
    sudo firewall-cmd --permanent --add-port=10259/tcp       # kube-schedule
    sudo firewall-cmd --permanent --add-port=8001/tcp       # dashboard
    sudo firewall-cmd --reload
fi


# Useful for ansible administrators
sudo yum install -y python3 python-argcomplete

# Download last code from master branch
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray || exit 1

# Install dependencies from ``requirements.txt``
# sudo yum install -y ansible-2.9.6 python-jinja2 python-netaddr
sudo pip3 install -r requirements.txt

# Copy ``inventory/sample`` as ``inventory/expert_cluster``
cp -rfp ../inventory/expert inventory/

# Add custom users
cp -rfp ../roles/adduser/defaults/main.yml roles/adduser/defaults/main.yml

###########################################################
# Update Ansible inventory file with inventory builder
# declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
# declare -a IPS="($my_ip)"

my_ip=$(hostname -i)

# To generate a new YAML inventory uncomment this line
# CONFIG_FILE=inventory/expert/hosts.yaml python3 contrib/inventory_builder/inventory.py "${IPS[@]}"
# OR replace value in place with sed
sed -i "s/MY_IP/$my_ip/" ./inventory/expert/hosts.yaml
###########################################################


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
    sudo systemctl start containerd
    sudo systemctl enable containerd
fi

# Enable docker
if ! sudo systemctl status docker 1>/dev/null; then
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
fi

## Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
ansible-playbook -i inventory/expert/hosts.yaml --become --become-user=root cluster.yml

# Enable kubectl configuration
mkdir -p "$HOME/.kube"
sudo cp -f -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Install and enable k8s dashboard | Still to test!
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.5/aio/deploy/recommended.yaml
kubectl proxy --address='0.0.0.0'
echo -e "\n# please paste the following line on your workstation...\nssh -L 8001:127.0.0.1:8001 $(hostname -i)\n\n# and paste the following token to get access to the dashboard\n`sudo /usr/local/bin/kubectl describe secret $(sudo /usr/local/bin/kubectl get secret | grep 'dashboard-admin' | awk '{print $1}') | grep 'token:' | awk -F':      ' '{print $2}'`"


