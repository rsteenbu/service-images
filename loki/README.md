# Loki

Grafana Loki log aggregation service for n100d. Receives logs from:
- Alloy syslog listener (port 1514) ← rsyslog (port 514) ← all Docker containers and remote hosts
- Alloy journal source (systemd journal on n100d)
- Alloy file source (nginx logs)

## Prerequisites

- Docker installed
- Storage volume mounted at `/ext/loki`
- rsyslog configured (see below)

## Bootstrap

### 1. Create storage directories

```bash
sudo mkdir -p /ext/loki /ext/alloy
sudo chown 120:120 /ext/loki
```

UID 120 is the `loki` user inside the container. `/ext/alloy` is Alloy's WAL storage and can be owned by root.

### 2. Configure rsyslog

rsyslog must accept syslog on UDP/TCP 514 and forward everything to Alloy on port 1514.

`/etc/rsyslog.d/10-listeners.conf`:
```
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")
```

`/etc/rsyslog.d/forward.conf`:
```
*.*  action(type="omfwd"
       protocol="tcp" target="n100d" port="1514"
       Template="RSYSLOG_SyslogProtocol23Format"
       TCP_Framing="octet-counted" KeepAlive="on"
       action.resumeRetryCount="-1"
       queue.type="linkedlist" queue.size="50000")
```

```bash
sudo systemctl restart rsyslog
```

### 3. Start Loki

```bash
cd ~/service-images/loki
docker compose up -d
```

### 4. Start Loki and Alloy

Alloy runs as a container in this compose project alongside Loki.

```bash
cd ~/service-images/loki
docker compose up -d
```

## Verify

```bash
# Loki is up
curl http://localhost:3100/ready

# Alloy is shipping logs
sudo journalctl -u alloy -f

# Query recent logs in Loki
curl -s -G 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={hostname="n100d"}' \
  --data-urlencode 'limit=5' | jq '.data.result[].stream'
```

## Data

Loki stores data at `/ext/loki` (mounted from host). Retention and storage config is in `loki-config.yml`.
