# klipper-exporter

Prometheus exporter for Klipper (Voron toolchanger). Built in-container from a pinned commit of our fork of [`scross01/prometheus-klipper-exporter`](https://github.com/scross01/prometheus-klipper-exporter).

## Source

Fork: <https://github.com/rsteenbu/prometheus-klipper-exporter>
Pinned ref: `2c6fa94b9a7ea11908df463d09a551f4f59fc596` (branch `feature/multiple-extruder-support`)

That commit adds dynamic multi-extruder discovery on top of upstream `development` (v0.16.0). It's the only patch beyond upstream.

## Build

`docker-compose build` clones the fork, checks out `EXPORTER_REF`, and builds the Go binary. To bump the version, either:

- Edit `EXPORTER_REF` in `Dockerfile` to a new commit SHA, OR
- Override at build time: `docker-compose build --build-arg EXPORTER_REF=<sha>`

Prefer SHAs over branch names for reproducibility.

## Deploy

    cd klipper-exporter
    docker-compose up -d --build

The container runs with `network_mode: host` and listens on `:9101`. Prometheus scrape config lives in `../prometheus/prometheus.yml`.

## Iterating on the exporter code

This directory does not carry the exporter source. To change exporter behavior, clone the fork separately, commit + push to the fork branch, then bump `EXPORTER_REF` here.

    git clone git@github.com:rsteenbu/prometheus-klipper-exporter.git
    cd prometheus-klipper-exporter
    git checkout feature/multiple-extruder-support
    # ... edit, commit, push ...
