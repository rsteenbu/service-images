#!/bin/bash
set -e

LOKI_HOST="${1:?Usage: install.sh <loki_host> <prometheus_host> [config_file]}"
PROMETHEUS_HOST="${2:?Usage: install.sh <loki_host> <prometheus_host> [config_file]}"
CONFIG_FILE="${3:-$(dirname "$0")/config.alloy}"

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
  "${CONFIG_FILE}" | sudo tee /etc/alloy/config.alloy > /dev/null

# Grant journal access
sudo usermod -aG systemd-journal alloy

# Grant docker access + deploy docker-events service only if Docker is present
if command -v docker >/dev/null 2>&1; then
  sudo usermod -aG docker alloy
  sudo cp "$(dirname "$0")/docker-events.service" /etc/systemd/system/docker-events.service
  sudo systemctl daemon-reload
  sudo systemctl enable docker-events
  sudo systemctl restart docker-events
  DOCKER_INSTALLED=1
else
  DOCKER_INSTALLED=0
fi

sudo systemctl enable alloy
sudo systemctl restart alloy

echo "Alloy installed and started."
echo "Verify with: sudo journalctl -u alloy -f"
if [ "$DOCKER_INSTALLED" = "1" ]; then
  echo "Docker events: sudo journalctl -u docker-events -f"
else
  echo "Docker not detected — skipped docker group and docker-events service."
fi
