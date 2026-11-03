# Actual Budget — deployment requirements

## Goal
Run [Actual Budget](https://actualbudget.org/) server in Docker, managed from this
`service-images` repo, following the same conventions as other services here.

## User decisions
- **Hostname:** `budget.steenburg.net`
- **Access:** External, gated by Authelia (bypass on internal LAN like `home.steenburg.net` / `voron.steenburg.net`)
- **Host port:** `5006` (Actual's default)

## Upstream reference
Based on the official compose at
`https://raw.githubusercontent.com/actualbudget/actual-server/master/docker-compose.yml`
with these upstream features preserved:
- `docker.io/actualbudget/actual-server:latest`
- `/data` volume mount inside container
- `healthcheck` block (`node src/scripts/health-check.js`)

## Repo conventions to apply
Derived from `grafana/`, `homebridge/`, `nginx/`:
- `network_mode: host` (no `ports:` section)
- `restart: always`
- Syslog logging to `n100d:514` with a `tag:` matching the service name
- Bind-mount persistent data under `/docker-volumes/<service>/`
- `version: '3.8'` at top of compose (matches existing files)

## Data
- use /ext/actualbudget for the the data storage

## Deliverables
1. **`actual-budget/docker-compose.yml`** — compose file above
2. **`nginx/sites-enabled/budget`** — Authelia-gated server block proxying
   `https://budget.steenburg.net` → `http://localhost:5006`. Pattern copied from
   `sites-enabled/mainsail` (voron). Includes:
   - `include /etc/nginx/snippets/authelia-auth.conf;`
   - `auth_request /authelia/authz;`
   - WebSocket upgrade headers (Actual uses WS for sync)
   - `client_max_body_size 20M` to match Actual's default upload limit
3. **`authelia/configuration.yml`** — append two rules under `access_control.rules`:
   ```yaml
   - domain: budget.steenburg.net
     networks:
       - internal
     policy: bypass
   - domain: budget.steenburg.net
     policy: one_factor
   ```

## Out of scope / user handles
- Create `/ext/actualbudget/` with appropriate ownership before `docker compose up`
- DNS: ensure `budget.steenburg.net` resolves to the nginx host (internal via `dnsmasq` on `rpi-dns01`, external via public DNS)
- TLS cert SAN: verify `/etc/letsencrypt/live/steenburg.net-0001/` cert covers `budget.steenburg.net`; if not, add it via certbot
- Deploy order after files land:
  1. `cd actual-budget && docker compose up -d`
  2. Reload Authelia: `cd authelia && docker compose restart`
  3. Reload nginx: `cd nginx && docker compose exec nginx nginx -s reload` (or `./reload-nginx-docker.sh`)

## Later / optional

### Direct API access from outside the network
Not needed for browser/PWA use (Authelia session cookie handles it). Add this
only when wiring in off-network automation: SimpleFIN/YNAB import jobs on a VPS,
iOS Shortcuts, n8n/Home Assistant/Node-RED flows, Telegram bots, Grafana
dashboards pulling from Actual, nightly backup scripts, etc. (In-network
automation is already covered by the LAN bypass rule.)

Approach: add a **second nginx server block** on a dedicated hostname
(e.g. `budget-api.steenburg.net`) proxying the same `localhost:5006`, with **no**
Authelia `auth_request`. Actual's own password gates the API.

Preferred over a `location /sync/` bypass on the main host:
- Smaller blast radius — a misconfig can't accidentally expose the UI
- Independent hardening (IP allowlist, rate limits, mTLS) without touching UI access
- Separate access logs for abuse spotting
- Authelia config stays untouched — the API hostname just isn't in it

Checklist when turning it on:
- Add `budget-api.steenburg.net` to the TLS cert SAN (certbot)
- Add DNS record (dnsmasq on rpi-dns01 for internal + public DNS)
- Consider `allow <known-source-IP>; deny all;` if the automation has a fixed source
- Confirm Actual's server password is strong (now the sole external gate)
