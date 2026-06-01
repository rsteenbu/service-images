# stop using the cloud config
sudo apt-get purge cloud-init -y
sudo rm -rf /etc/cloud/ /var/lib/cloud/

# install docker daemon and docker-compose
sudo apt update
sudo apt install docker.io docker-compose

sudo cp interfaces /etc/network/
echo 8021q >> /etc/modules
apt-get install -y vlan ifupdown
modprobe 8021q
# Disable dhcpcd if it's running (conflicts with ifupdown)
systemctl disable --now dhcpcd
systemctl enable networking
ifup -a
