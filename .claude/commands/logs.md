# Query Loki Logs

Query the Loki instance at `http://localhost:3100` using the Bash tool and `curl`.

The user will describe what they want to see. Translate that into a LogQL query, run it, and display the results clearly.

## Available labels (stream selectors)

| Label | Example values | Notes |
|---|---|---|
| `application` | `dnsmasq`, `dnsmasq-dhcp`, `nginx`, `grafana`, `loki`, `alloy`, `postfix`, `mongodb`, `prometheus`, `homebridge-kids`, `homebridge-parents`, `kernel`, `sshd`, `systemd`, ... | Program/process name parsed by rsyslog from the syslog message |
| `dnsmasq_service` | `dns`, `dhcp` | Splits dnsmasq logs into DNS queries vs DHCP events |
| `hostname` | `192.168.1.5` (rpi-dns01), `n100d.steenburg.net` | Source host |
| `severity` | `info`, `error`, `warning`, `debug`, `notice` | Syslog severity |
| `facility` | `daemon`, `kern`, `user`, `mail`, `local0`, `local1`, ... | Syslog facility |
| `service_name` | mirrors `application` | Set by alloy syslog source |
| `connection_hostname` | `n100d.steenburg.net.,n100d` | Alloy TCP connection origin |
| `server_name` | nginx virtual host name | nginx logs only |
| `remote_addr` | client IP | nginx logs only |

## Structured metadata (use with `|` filter, not `{}` selector)

| Field | Notes |
|---|---|
| `src_ip` | Source IP of DNS queries — extracted from dnsmasq DNS log lines matching `from <IP>` |

## Common query patterns

```logql
# All logs from a specific host
{hostname="192.168.1.5"}

# DNS queries from a specific client IP
{dnsmasq_service="dns"} | src_ip = "192.168.1.12"

# DNS queries from a whole subnet
{dnsmasq_service="dns"} | src_ip =~ "192.168.3\\..*"

# DHCP events on a specific VLAN interface
{dnsmasq_service="dhcp"} |~ "eth0\\.30"

# nginx errors
{application="nginx"} | severity = "error"

# SSH logins
{application="sshd"} |~ "Accepted"

# All logs from a specific application, last N lines
{application="postfix"}

# Errors across all sources
{severity="error"}

# IoT VLAN syslog (local0 facility)
{facility="local0"}
```

## Loki API curl pattern

```bash
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query=<LOGQL>' \
  --data-urlencode "start=$(date -d '<TIME> ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode "limit=<N>" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for stream in data['data']['result']:
    for ts, line in stream['values']:
        print(line)
"
```

Default to `limit=50` and `start` of `1 hour ago` unless the user specifies otherwise. If the user asks for a count or stats, use the `/loki/api/v1/query` endpoint with a `count_over_time` or `rate` metric query instead.

When displaying results, show the raw log lines. If the result set is large, summarize patterns rather than printing every line.
