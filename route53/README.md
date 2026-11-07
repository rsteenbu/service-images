# route53

Hourly cron script that keeps the external DNS record for home in sync with the ISP's dynamic public IP.

## What it does

- Reads the current public IP via `curl http://ifconfig.net`
- UPSERTs an A record for `home.steenburg.net` in Route53 (zone `Z3LL68C7O2MBKT`, TTL 300)
- Logs the AWS CLI response to syslog via `logger` (shows up in Loki with the rest of system syslog)

## Why this exists

`steenburg.net` is authoritative on AWS Route53 (external DNS). External clients reach services via `home.steenburg.net` → ISP public IP → Mikrotik port-forwards 80/443 to n100d/nginx → Authelia for protected services. Internal clients see `steenburg.net` subdomains via dnsmasq split-DNS pointed straight at 192.168.1.12, bypassing hairpin NAT. This script keeps the external half alive across ISP IP changes.

See `../CLAUDE.md` → *Auth / external access* for the full topology.

## Deploy

Install the hourly cron (as `rsteenbu` on n100d):

    crontab -e
    0 * * * * /home/rsteenbu/service-images/route53/update.sh

## Dependencies

- `aws` CLI configured for `rsteenbu` with route53 write access to zone `Z3LL68C7O2MBKT` (`~/.aws/credentials`)
- `curl`, `logger` (standard util-linux)
