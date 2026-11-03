# Actual Budget — test plan

Each section maps to a `REQUIREMENTS.md` section. Each test lists a command to
run and the expected result. Run from the service-images repo root unless noted.

## 1. Container health (upstream features)

### 1.1 Image is the official one
```
docker compose -f actual-budget/docker-compose.yml config | grep image:
```
Expect: `image: docker.io/actualbudget/actual-server:latest`

### 1.2 Container starts and stays up
```
cd actual-budget && docker compose up -d
sleep 30
docker compose ps
```
Expect: `actual_server` with status `Up` and health `healthy`.

### 1.3 Healthcheck is wired up
```
docker inspect --format '{{json .State.Health}}' $(docker compose -f actual-budget/docker-compose.yml ps -q) | jq
```
Expect: `Status: "healthy"`, and `Log[0].Output` from `node src/scripts/health-check.js`.

### 1.4 Server responds on 5006
```
curl -sf http://localhost:5006/ -o /dev/null -w '%{http_code}\n'
```
Expect: `200` (or a redirect — any 2xx/3xx proves the server bound to the port).

## 2. Repo conventions

### 2.1 Host networking (no port mapping needed)
```
docker inspect --format '{{.HostConfig.NetworkMode}}' $(docker compose -f actual-budget/docker-compose.yml ps -q)
```
Expect: `host`.

### 2.2 Restart policy is `always`
```
docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' $(docker compose -f actual-budget/docker-compose.yml ps -q)
```
Expect: `always`.

### 2.3 Syslog driver pointed at n100d
```
docker inspect --format '{{.HostConfig.LogConfig}}' $(docker compose -f actual-budget/docker-compose.yml ps -q)
```
Expect: driver `syslog`, config includes `syslog-address: udp://n100d:514` and `tag: actual-budget`.

### 2.4 Logs flowing to Loki/Grafana
Open Grafana → Explore → Loki, query:
```
{application="actual-budget"} |= ""
```
Expect: recent lines from container startup (give it ~1 min after `up -d`).

### 2.5 Docker JSON log file is NOT in use
With the syslog driver active, Docker's local JSON log should stay empty.
```
docker inspect --format '{{.LogPath}}' $(docker compose -f actual-budget/docker-compose.yml ps -q)
# then as root/sudo on the docker host:
sudo wc -c "$(docker inspect --format '{{.LogPath}}' $(docker compose -f actual-budget/docker-compose.yml ps -q))"
```
Expect: file size `0` (or very small). If it's growing, the syslog driver isn't
actually attached and logs are falling back to the default json-file driver.
Note: `docker logs <container>` will NOT work with the syslog driver — that's
expected, not a bug.

### 2.6 n100d is receiving the syslog UDP packets
Trigger some noise (`docker compose restart` the container) then on `n100d`:
```
sudo tcpdump -ni any -A 'udp port 514' | grep -i actual-budget
```
Expect: packets within a few seconds, body contains the tag `actual-budget` and
a recent log line. Also check the rsyslog landing file (per `rsyslog/` configs
in this repo):
```
ssh n100d 'sudo tail -n 20 /var/log/remote/actual-budget.log'   # path may differ — adjust to your rsyslog ruleset
```
Expect: recent lines matching what the container just emitted.

### 2.7 Loki labels are correct
In Grafana → Explore → Loki, run:
```
{application="actual-budget"} | json | line_format "{{.__labels__}}"
```
Then click a line to inspect labels. Expect:
- `application="actual-budget"` (set from the Docker syslog `tag`)
- `host` label pointing at the Docker host (not `n100d` — `n100d` relays, it's
  not the origin)
- `severity` populated (`info`, `notice`, `error` as appropriate — see 2.8)

### 2.8 Severity mapping is not stuck on "error"
Known trap (see dnsmasq incident in memory): Docker's syslog driver maps all
stderr output to `severity=error`, which lights up dashboards falsely. Verify
Actual's informational startup lines aren't all `error`:
```
{application="actual-budget", severity="error"} | json
```
Expect: either empty, or only genuine error lines (stack traces, failed
healthchecks). If normal startup messages are showing up as `error`, add an
Alloy `stage.match` override for `application="actual-budget"` like the one
already applied to dnsmasq.

### 2.9 Log continuity across container restart
```
docker compose -f actual-budget/docker-compose.yml restart
```
In Grafana, query the last 10 minutes:
```
{application="actual-budget"} |= ""
```
Expect: a continuous stream — pre-restart lines, a shutdown line, a startup
line, then post-restart traffic. No gap longer than the ~5–10s restart window.

### 2.10 No secrets leaking into logs
```
{application="actual-budget"} |~ "(?i)(password|token|secret|authorization|cookie)"
```
Expect: zero matches, or only lines that reference these words structurally
(e.g. "set password endpoint called") rather than exposing values. If a real
token or password shows up, redact at the Alloy stage before it hits Loki.

## 3. Data persistence

### 3.1 Bind mount is `/ext/actualbudget` → `/data`
```
docker inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' $(docker compose -f actual-budget/docker-compose.yml ps -q)
```
Expect: a line `/ext/actualbudget -> /data`.

### 3.2 Host directory is writable by the container
```
ls -la /ext/actualbudget/
```
Expect: directory exists and contains Actual's state files (`server-files/`, `user-files/`, `account.sqlite`, etc.) after first login.

### 3.3 Data survives a restart
1. Create a test budget via the web UI, add one transaction.
2. `docker compose -f actual-budget/docker-compose.yml restart`
3. Reload the browser.
Expect: budget and transaction still present.

## 4. Nginx reverse proxy

### 4.1 Nginx config parses
```
docker compose -f nginx/docker-compose.yml exec nginx nginx -t
```
Expect: `syntax is ok` and `test is successful`.

### 4.2 TLS cert covers budget.steenburg.net
```
openssl s_client -connect budget.steenburg.net:443 -servername budget.steenburg.net </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```
Expect: SAN list includes `DNS:budget.steenburg.net`.

### 4.3 DNS resolves (internal and external)
```
dig +short budget.steenburg.net @rpi-dns01
dig +short budget.steenburg.net @1.1.1.1
```
Expect: both return the nginx host's IP (internal LAN IP vs. public IP as appropriate).

### 4.4 WebSocket upgrade headers present in config
```
grep -A20 'server_name budget.steenburg.net' nginx/sites-enabled/budget
```
Expect: `proxy_set_header Upgrade $http_upgrade;` and `proxy_set_header Connection "Upgrade";`.

## 5. Authelia access control

### 5.1 Internal LAN bypasses Authelia
From a machine on `192.168.0.0/16`:
```
curl -sIk https://budget.steenburg.net/ | head -1
```
Expect: `HTTP/2 200` (or 302 to the Actual login page) — **no** redirect to `auth.steenburg.net`.

### 5.2 External request is challenged by Authelia
From an off-LAN host (phone on cellular, VPS, etc.):
```
curl -sIk https://budget.steenburg.net/
```
Expect: `302 Found` with `Location:` header pointing at `https://auth.steenburg.net/...?rd=https://budget.steenburg.net/`.

### 5.3 After Authelia login, UI loads
In an off-LAN browser:
1. Visit `https://budget.steenburg.net/`
2. Complete Authelia one-factor login
Expect: Actual's own login page appears; sign in with Actual's server password and the budget loads.

### 5.4 Authelia session cookie persists sync WebSocket
With the UI open from an external browser:
1. DevTools → Network → filter WS
2. Make a change (edit a transaction).
Expect: a `wss://budget.steenburg.net/...` connection stays open and the change propagates without re-prompting for Authelia login.

## 6. End-to-end mobile use

### 6.1 Mobile browser on cellular (external)
1. Disable WiFi on phone.
2. Visit `https://budget.steenburg.net/`.
Expect: Authelia login → Actual login → budget loads → edits sync.

### 6.2 Mobile browser on home WiFi (internal bypass)
1. Join home WiFi.
2. Visit `https://budget.steenburg.net/` in a private/incognito tab (no cached Authelia cookie).
Expect: goes straight to Actual's login — no Authelia prompt.

### 6.3 PWA install
1. In mobile Chrome/Safari, use "Add to Home Screen".
2. Launch from the home screen icon.
Expect: fullscreen Actual UI, offline-capable after first load.

## 7. Reload & recovery

### 7.1 Nginx reload picks up the new site
```
cd nginx && docker compose exec nginx nginx -s reload
docker compose logs --tail=20 nginx
```
Expect: no error lines; `budget.steenburg.net` serves normally after reload.

### 7.2 Authelia restart picks up new rules
```
cd authelia && docker compose restart
docker compose logs --tail=50 authelia | grep -i "budget\|rule\|error"
```
Expect: no errors; config load log shows the new domain.

### 7.3 Full host reboot
```
sudo reboot
# wait, then from another machine:
curl -sIk https://budget.steenburg.net/
```
Expect: service back up without manual intervention (verifies `restart: always`
and that compose project auto-starts via systemd or `docker start` policy).

## 8. Deferred (not tested until implemented)

- Direct API server block (`budget-api.steenburg.net`) — see REQUIREMENTS.md
  "Later / optional". Add tests here when that block is enabled.
