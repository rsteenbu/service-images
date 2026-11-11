# service-images

Home network infrastructure. One docker-compose project per subdirectory, deployed across **n100d** (main host, where this repo lives) and **rpi-dns01** (remote DNS/DHCP). Config is the source of truth — every service is reproducible from this repo.

## Topology

- **n100d** (192.168.1.12) — Loki/Alloy/Grafana/Prometheus stack, Nginx reverse proxy, Authelia, Postfix, Homebridge, Actual Budget, MongoDB, SFTP, rsyslog
- **rpi-dns01** — dnsmasq (DNS + DHCP). Config is edited here, synced there. **DHCP leases and runtime state live on rpi-dns01, not locally** — ssh there to inspect.
- **Mikrotik devices (7)** — router + switch + 5 APs, all CAPsMAN-managed by `mikro-router`. See [[project_mikrotik_network]] for IPs/VLAN map.

## Service directories

Each is a `docker-compose` project unless noted. Deploy with `cd <dir> && docker-compose up -d`.

- `loki/` — Loki + containerized Alloy (SNMP scrape of all 7 Mikrotiks, syslog listener on 1514, journal reader, docker log scraper). Primary observability hub on n100d.
- `alloy/` — **bare-metal Alloy** installer (`install.sh`) + shared template config; used on rpi-dns01 (not currently on n100d — see migration note below)
- `prometheus/`, `grafana/` — metrics + dashboards. Dashboards are provisioned from `grafana/provisioning/dashboards/` (hot-reloaded every 30s). Datasource UIDs: Prometheus `admcgbr6g84cgf`, Loki `edqunhtg56n7ka`.
- `dnsmasq/` — config for rpi-dns01 (**not run locally**); authoritative for `steenburg.net`; holds static DHCP entries and split-DNS A records (see Auth section). Includes an **autoheal sidecar** (`willfarrell/autoheal`) that restarts dnsmasq when its healthcheck flips to `unhealthy` — dnsmasq is labeled `autoheal=true`.
- `rsyslog/` — host rsyslog drop-ins **symlinked into `/etc/rsyslog.d/`** (not a container). Receives container syslog on `udp://n100d:514`.
- `nginx/` — reverse proxy; vhosts in `sites-enabled/`. Certbot renewal fires `nginx/reload-nginx-docker.sh` to reload the container.
- `authelia/` — auth gateway in front of nginx (see Auth section)
- `homebridge/` — HomeKit bridge; `control_network_access.py` toggles Mikrotik firewall rules via creds in docker-compose secrets
- `klipper-exporter/` — custom Prometheus exporter for the Voron. `Dockerfile` clones our fork at a pinned SHA (see `klipper-exporter/README.md`). Exporter source is NOT in this repo — iterate in a separate clone of `github.com/rsteenbu/prometheus-klipper-exporter`, then bump `EXPORTER_REF`.
- `route53/` — `update.sh` runs hourly via `rsteenbu`'s cron on n100d; UPSERTs `home.steenburg.net` A record in Route53 (zone `Z3LL68C7O2MBKT`) to the ISP's dynamic public IP. External half of the auth/split-DNS story.
- `dnsmasq/setup/rpi-dns01-vlans.sh` — one-time `nmcli` bootstrap to create VLAN 10/20/30/40/50 interfaces on rpi-dns01 so dnsmasq can bind each subnet (.5 on each). Not idempotent — re-bootstrap requires deleting existing nmcli connections first.
- Others: `actual-budget/`, `mongodb/`, `postfix/` (Gmail relay), `sftp/` (Mikrotik config backup target, replaced vsftpd)

## Auth / external access (Authelia)

- **Internal clients** (source IP in `192.168.0.0/16`): bypass Authelia entirely.
- **External clients**: Authelia `one_factor` login via `auth.steenburg.net`.
- **Protected externally**: Grafana, Voron (Mainsail). **Blocked externally**: homebridge, ntop.
- **External DNS**: `steenburg.net` is authoritative on AWS Route53 (zone `Z3LL68C7O2MBKT`). `home.steenburg.net` is kept in sync with the ISP's dynamic public IP by `route53/update.sh` (hourly cron on n100d).
- **Split-DNS**: dnsmasq resolves `steenburg.net` subdomains to `192.168.1.12` for internal clients. This avoids hairpin NAT — if omitted, Authelia would see the router's IP for internal requests and auth decisions would break.
- Nginx wiring: `nginx/snippets/authelia-auth.conf` + `auth_request` directive per vhost.

## Observability (local to n100d)

- Loki: `http://localhost:3100` — `logcli query '…' --since=Nm` or `curl /loki/api/v1/query_range`
- Prometheus: `http://localhost:9090`
- **PromQL for Mikrotik**: filter `job=~"integrations/snmp/mikro.*"` + `device="mikro-<name>"`.
- **WiFi client data**: always query `device="mikro-router"` — CAPsMAN centralizes it; `mtxrWlApClientCount` is 0 on managed APs.

## Conventions

- **Container redeploy after config change**: `docker-compose up -d` from the service's directory — do NOT `docker restart <name>`, it misses volume/env edits.
- **Logging**: all n100d containers log via the Docker `syslog` driver to `udp://n100d:514`. New services should copy the `logging:` block from an existing `docker-compose.yml` — don't introduce `json-file` services.
- **Secrets**: use docker-compose `secrets:` (file-based), not `.env`. Established for Mikrotik creds; follow the same pattern for new services.
- **Static DHCP + DNS entries**: belong in `dnsmasq/` (then commit + sync to rpi-dns01). Avoid adding DNS aliases for hosts with dynamic IPs — the alias goes stale (see 2cbdc7a, lutron-blinds revert).
- **Git**: branch is `main`, remote is `origin` (GitHub). Commit per feature; recent commits set the imperative-lowercase style.

## Durable gotchas (don't re-learn these)

- **dnsmasq severity=error**: Docker's syslog driver forces stderr → `LOG_ERR`. A `stage.match` in `loki/alloy-config.alloy` under `loki.process "syslog"` overrides severity to `info` for `application="dnsmasq"`. **Must stay first** in that pipeline. See [[project_dnsmasq_severity]].
- **Loki DHCP label split (2026-05-23 22:00)**: old = `application="dnsmasq-dhcp"`, new = `dnsmasq_service="dhcp"`. For historical ranges, union both. See [[feedback_loki_dhcp_label]].
- **Alloy journal relabeling**: `relabel_rules = …` must sit inside `loki.source.journal` (labels are stripped before `forward_to`); journal fields drop their leading underscore (`__journal_systemd_unit`, not `__journal__systemd_unit`). See [[feedback_alloy_journal_relabeling]].
- **dnsmasq self-heal**: healthcheck (`nslookup home.steenburg.net 127.0.0.1`) only **detects** upstream deadlock; it does not recover on its own. Recovery is done by the `autoheal` sidecar in `dnsmasq/docker-compose.yml`, which restarts any container labeled `autoheal=true` when Docker flips it to `unhealthy`. Don't strip either half (fbed73f added the healthcheck; the sidecar was added after a 2026-11-10 outage where dnsmasq stayed hung for ~13 min with no recovery).
- **Mikrotik config backups**: `/home/ftp-files/<device>-<YYYYMMDD>.rsc`, owned by `ftp-files`; may need `sudo` to read. See [[reference_mikrotik_backups]].

## In flight

- **Alloy bare-metal migration on n100d is paused** (2026-06-27; migration scaffolding purged 2026-09-18; a mid-flight revert went in as 06f4e72). Current state: Alloy on n100d runs as Docker container `loki_alloy_1` reading `loki/alloy-config.alloy`. See [[project_alloy_migration]] before resuming.

## Deeper context

Project memory: `~/.claude/projects/-home-rsteenbu-service-images/memory/MEMORY.md`.
