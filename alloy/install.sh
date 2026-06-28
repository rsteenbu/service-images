#!/bin/bash
set -e

LOKI_HOST="${1:?Usage: install.sh <loki_host> <prometheus_host>}"
PROMETHEUS_HOST="${2:?Usage: install.sh <loki_host> <prometheus_host>}"

# Add Grafana APT repo
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | \
  sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y alloy

# Deploy config with host substitutions
sed \
  -e "s/LOKI_HOST/${LOKI_HOST}/g" \
  -e "s/PROMETHEUS_HOST/${PROMETHEUS_HOST}/g" \
  "$(dirname "$0")/config.alloy" | sudo tee /etc/alloy/config.alloy > /dev/null

# Grant journal and docker access
sudo usermod -aG systemd-journal alloy
sudo usermod -aG docker alloy

sudo systemctl enable alloy
sudo systemctl restart alloy

# Deploy Docker events logger service
sudo cp "$(dirname "$0")/docker-events.service" /etc/systemd/system/docker-events.service
sudo systemctl daemon-reload
sudo systemctl enable docker-events
sudo systemctl restart docker-events

echo "Alloy installed and started."
echo "Verify with: sudo journalctl -u alloy -f"
echo "Docker events: sudo journalctl -u docker-events -f"
