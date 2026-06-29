# Grafana Alloy

Bare-metal Alloy agent for shipping logs and metrics to Loki and Prometheus. Runs on any Debian/Raspbian host. All Docker containers are expected to log via the syslog driver — Alloy does not collect Docker logs directly.

## Configs

| Config | Used by | Collects |
|--------|---------|----------|
| `alloy/config.alloy` | Simple hosts (e.g. rpi-dns01) | systemd journal, node_exporter metrics |
| `loki/alloy-config.alloy` | n100d | systemd journal, node_exporter metrics, SNMP (Mikrotik), nginx logs, syslog listener (port 1514), docker-events |

## Install — simple host (e.g. rpi-dns01)

```bash
cd ~/service-images
./alloy/install.sh <loki_host> <prometheus_host>
```

Example:

```bash
./alloy/install.sh n100d n100d
```

## Install — n100d

n100d uses an extended config. The SNMP config file must be in place before starting Alloy.

```bash
cd ~/service-images
sudo cp loki/snmp_localbuild.yml /etc/alloy/snmp_localbuild.yml
./alloy/install.sh n100d n100d loki/alloy-config.alloy
```

Then take down the docker-based alloy (now replaced):

```bash
cd loki && docker compose up -d
```

## What install.sh does

1. Adds the Grafana APT repository and installs `alloy`
2. Writes `/etc/alloy/config.alloy` from the specified config file, substituting `LOKI_HOST` and `PROMETHEUS_HOST`
3. Adds the `alloy` user to `systemd-journal` and `docker` groups
4. Enables and starts the `alloy` systemd service
5. Installs `docker-events.service`, enables and starts it

## docker-events service

`docker-events.service` runs `docker events --format '{{json .}}'` as a systemd unit. Its output goes to the journal and is picked up by the `loki.source.journal "docker_events"` component in the Alloy config, labeled `application="docker"`.

Useful for querying healthcheck failures:

```logql
{hostname="n100d", application="docker"} |= "health_status: unhealthy"
```

## Verify

```bash
# Alloy logs
sudo journalctl -u alloy -f

# Docker events
sudo journalctl -u docker-events -f

# Node metrics in Prometheus
curl -s -G 'http://<prometheus_host>:9090/api/v1/query' \
  --data-urlencode 'query=node_uname_info{job="integrations/node_exporter"}' | jq '.data.result[].metric'
```

## Log labels

**Journal logs** (`loki.source.journal`):

| Label | Value |
|-------|-------|
| `hostname` | system hostname |
| `unit` | systemd unit name |
| `application` | syslog identifier |

**Syslog logs** (`loki.source.syslog`, n100d only — receives from other hosts via rsyslog):

| Label | Value |
|-------|-------|
| `hostname` | originating host |
| `application` | syslog app name |
| `severity` | syslog severity |
| `facility` | syslog facility |
| `dnsmasq_service` | `dns` or `dhcp` (dnsmasq logs only) |
