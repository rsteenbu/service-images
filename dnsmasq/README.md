apt-get install -y vlan ifupdown
modprobe 8021q
# Disable dhcpcd if it's running (conflicts with ifupdown)
systemctl disable --now dhcpcd
systemctl enable networking
ifup -a
