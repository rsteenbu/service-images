#!/bin/sh
# One-time VLAN bootstrap for rpi-dns01.
#
# Creates tagged VLAN interfaces on eth0 so dnsmasq can bind each subnet and
# serve DHCP per-VLAN. VLAN IDs mirror the Mikrotik router/CAPsMAN config:
#   10 = home   192.168.1.0/24  (primary, holds the default gateway)
#   20 = admin  192.168.2.0/24
#   30 = iot    192.168.3.0/24
#   40 = kids   192.168.4.0/24
#   50 = guest  192.168.5.0/24
# rpi-dns01 is .5 on every subnet.
#
# NOT idempotent: `nmcli connection add` fails if the connection exists.
# To re-bootstrap, delete the existing connections first:
#   sudo nmcli connection delete admin iot kids guest home

sudo nmcli connection add type vlan con-name admin dev eth0 id 20
sudo nmcli connection add type vlan con-name iot dev eth0 id 30
sudo nmcli connection add type vlan con-name kids dev eth0 id 40
sudo nmcli connection add type vlan con-name guest dev eth0 id 50

sudo nmcli connection modify admin ipv4.addresses 192.168.2.5/24
sudo nmcli connection modify admin ipv4.method manual

sudo nmcli connection modify iot ipv4.addresses 192.168.3.5/24
sudo nmcli connection modify iot ipv4.method manual

sudo nmcli connection modify kids ipv4.addresses 192.168.4.5/24
sudo nmcli connection modify kids ipv4.method manual

sudo nmcli connection modify guest ipv4.addresses 192.168.5.5/24
sudo nmcli connection modify guest ipv4.method manual

nmcli connection add type vlan con-name home dev eth0 id 10
nmcli connection modify home ipv4.addresses 192.168.1.5/24
nmcli connection modify home ipv4.gateway 192.168.1.1
nmcli connection up home

nmcli device show eth0
nmcli device set eth0 managed no
