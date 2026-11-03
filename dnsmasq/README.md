# dnsmasq (rpi-dns01)

## Host install

```
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
```

## Adding a new split-horizon name (`foo.steenburg.net`)

Services here are reachable from both LAN and internet under the same hostname.
Internal clients hit nginx on `192.168.1.12` directly; external clients hit the
public IP via a CNAME chain. Both halves must be configured or you'll get the
"A and CNAME both returned" issue (invalid per RFC 1912 — different clients
behave differently).

### External (public DNS)

At your public DNS provider, add a CNAME:

```
foo.steenburg.net.   CNAME   giant.steenburg.net.
```

`giant.steenburg.net` already CNAMEs to `steenburg.net`, which has the A record
for the public IP. New external services only need the one CNAME.

### Internal (dnsmasq on rpi-dns01)

Two files in this directory, both required:

**1. `hosts`** — append the new name to the `192.168.1.12` line (keeps the
hostnames list in one place; `dnsmasq` serves it via `expand-hosts`):

```
192.168.1.12  n100d home home.steenburg.net ... foo.steenburg.net
```

**2. `dnsmasq.conf`** — add TWO lines in the "Resolve steenburg.net subdomains"
block (around line 722). The `address=` gives the A record; the `local=` tells
dnsmasq to be fully authoritative for that name:

```
address=/foo.steenburg.net/192.168.1.12
local=/foo.steenburg.net/
```

**Why both lines?** `address=/` alone only handles A queries — dnsmasq will
still forward CNAME, AAAA, etc. queries upstream and return whatever's there.
Clients then follow the external CNAME chain and leave the LAN. `local=/` tells
dnsmasq "I'm authoritative for this name, never forward any query type for it"
— so other types return NXDOMAIN and the A record wins cleanly. Omitting
`local=/` is the exact bug that caused `budget.steenburg.net` to leak out to
the public IP from Mac clients. The `hosts` entry is just for the readable
inventory of names on `192.168.1.12`.

### Deploy

```
# from this directory, on your workstation:
scp hosts dnsmasq.conf rpi-dns01:/path/to/dnsmasq/   # adjust path to deployment layout
ssh rpi-dns01 'sudo docker compose -f /path/to/dnsmasq/docker-compose.yml restart'
```

### Verify

```
# internal — should return ONE A record and nothing else:
dig +noall +answer foo.steenburg.net @rpi-dns01

# external — should return the CNAME chain ending in the public A:
dig +noall +answer foo.steenburg.net @1.1.1.1

# from a client (e.g. Mac) — should show the internal A, no CNAMEs:
host foo.steenburg.net
```

If `host` shows both an A record *and* a CNAME chain, the `address=/` line is
missing from `dnsmasq.conf` or dnsmasq wasn't reloaded.

### Don't forget

- **TLS cert SAN:** `foo.steenburg.net` must be on the cert used by nginx
  (`/etc/letsencrypt/live/steenburg.net-*`). Add via certbot and reload nginx.
- **nginx server block:** add a `sites-enabled/foo` entry proxying to the
  backend service.
- **Authelia rules** (if gating externally): add bypass+one_factor rules to
  `authelia/configuration.yml` under `access_control.rules`.
