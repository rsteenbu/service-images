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

# Grant journal access
sudo usermod -aG systemd-journal alloy

sudo systemctl enable alloy
sudo systemctl restart alloy

echo "Alloy installed and started."
echo "Verify with: sudo journalctl -u alloy -f"
