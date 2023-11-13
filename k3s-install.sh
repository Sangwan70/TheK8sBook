echo "Installing dnf-utils and common container-tools"
echo "-----------------------------------------------------"

dnf install -y dnf-utils
dnf module install -y container-tools/common
echo "-----------------------------------------------------"
read -p "Press any key to continue ..."
echo "Downloading necessary software"
echo "-----------------------------------------------------"

if [ ! -f './helm-v3.13.2-linux-amd64.tar.gz' ]; then
   wget https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz
fi

if [ ! -f './cert-manager.crds.yaml' ]; then
   wget https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
fi

if [ ! -f 'helm-v3.13.2-linux-amd64.tar.gz' ]; then
        echo "Download of helm-v3.13.2-linux-amd64.tar.gz Failed. Check internet connectiona and try again!"
        exit 1
fi
if [ ! -f 'cert-manager.crds.yaml' ]; then
        echo "Download of cert-manager.crds.yaml Failed. Check internet connectiona and try again!"
        exit 1
fi

echo "-----------------------------------------------------"
echo "Done!"

echo "SElinux Configuration..."
echo "-----------------------------------------------------"

if [ ! `getenforce` = "Disabled" ]; then
   setenforce 0
   sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
else
   echo "SELinux already disabled! Moving on.."
fi

echo "Downloading and installing kubectl and helm binaries ..."
echo "-----------------------------------------------------"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

if [ ! -f kubectl ]; then
        echo "Download of kubectl Failed. Check internet connectiona and try again!"
        exit 1
fi

if [ ! -f 'kubectl.sha256' ]; then
        echo "Download of kubectl.sha256 Failed. Check internet connectiona and try again!"
        exit 1
fi

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
install -o root -g root -m 0755 kubectl /usr/bin/kubectl
kubectl version --client --output=yaml
tar -xzf helm-v3.13.2-linux-amd64.tar.gz
install -o root -g root -m 0755 linux-amd64/helm /usr/bin/helm
echo
echo "Done!"
echo "-----------------------------------------------------"
read -p "Press any key to continue ..."
echo "Opening firewall ports ..."
firewall-cmd --zone=public --add-masquerade --permanent 2> /dev/null
firewall-cmd --permanent --add-port={2379,2380,7946,8472,80,443,6443,10250,8080}/tcp 2> /dev/null
firewall-cmd --permanent --add-port={2376,9099,10254}/tcp 2> /dev/null
firewall-cmd --permanent --add-port=30000-32767/tcp 2> /dev/null
firewall-cmd --permanent --add-port=8472/udp 2> /dev/null
firewall-cmd --permanent --add-port=30000-32767/udp 2> /dev/null
firewall-cmd --reload
echo
echo "Done!"
echo "-----------------------------------------------------"
read -p "Press any key to continue ..."
echo "Kernel Module and IP forwarding ..."

modprobe br_netfilter

if [ ! -f '/etc/modules' ]; then
   echo "br_netfilter" >> /etc/modules
fi

echo '1' > sudo /proc/sys/net/bridge/bridge-nf-call-iptables

if [ ! `grep 'net.bridge.bridge-nf-call-iptables=1' /etc/sysctl.conf` ]; then
  echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf
  echo 'net.ipv4.ip_forward=1' >>  /etc/sysctl.conf
  sysctl -p
fi

echo
echo "Done!"
echo "-----------------------------------------------------"
read -p "Press any key to continue ..."
echo " Installing Light weight Kubernetes, K3S..."
IPADDR=$(hostname -I | awk '{print $2}')
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.3+k3s2" K3S_TOKEN=skillpedia#1 sh -s - server --node-ip=${IPADDR} --advertise-address=${IPADDR} --cluster-init

if [ -d ~/.kube ]; then
   rm -rf .kube
fi

mkdir ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

echo
echo "Done!"
echo "-----------------------------------------------------"
read -p "Press any key to continue ..."
echo " Verify ..."

kubectl get pods -o wide --all-namespaces

helm repo add jetstack https://charts.jetstack.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --set controller.service.type=NodePort --version 4.0.18 --create-namespace
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --version v1.7.1
kubectl apply -f cert-manager.crds.yaml

