# Grafana Alloy

Ships systemd journal logs and Docker container logs to Loki, and OS metrics to Prometheus from any Debian/Raspbian host.

## Fresh install

```bash
git clone <service-images-repo>
cd service-images/alloy
./install.sh <loki_host> <prometheus_host>
```

Example:

```bash
./install.sh n100d n100d
```

The script will:
1. Add the Grafana APT repository
2. Install Alloy
3. Write `/etc/alloy/config.alloy` with the provided hostnames
4. Add the `alloy` user to the `systemd-journal` group for journal access
5. Enable and start the `alloy` systemd service

To also collect Docker container logs, add `alloy` to the `docker` group and restart:

```bash
sudo usermod -aG docker alloy
sudo systemctl restart alloy
```

## Verify

```bash
sudo journalctl -u alloy -f
```

Check metrics are arriving in Prometheus:

```bash
curl -s -G 'http://<prometheus_host>:9090/api/v1/query' \
  --data-urlencode 'query=node_uname_info{job="integrations/node_exporter"}' | jq '.data.result[].metric'
```

## Labels

| Label      | Value                        |
|------------|------------------------------|
| `hostname` | host's system hostname       |
| `instance` | host's system hostname       |
| `job`      | `integrations/node_exporter` |

Logs are labeled with `hostname`, `unit`, and `application` (from the journal).
