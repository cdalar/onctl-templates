#!/bin/bash
# install docker
# curl https://templates.onctl.com/docker/docker.sh | bash

# cat <<EOF > prometheus.yml
# global:
#   scrape_interval: 10s
# scrape_configs:
#   - job_name: myvm
#     metrics_path: /metrics
#     static_configs:
#       - targets: [ 'localhost:9100' ]
# EOF
# cat <<EOF > docker-compose.yml
# services:
#   prometheus:
#     image: prom/prometheus:v3.0.0
#     container_name: prometheus
#     network_mode: "host"
#     ports:
#       - "9090:9090"
#     volumes:
#       - ${PWD}/prometheus.yml:/etc/prometheus/prometheus.yml
#   grafana:
#     image: grafana/grafana:8.4.4-ubuntu
#     container_name: grafana
#     network_mode: "host"
#     ports:
#       - "3000:3000"
#   node_exporter:
#     image: quay.io/prometheus/node-exporter:latest
#     container_name: node_exporter
#     command:
#       - '--path.rootfs=/host'
#     network_mode: host
#     pid: host
#     restart: unless-stopped
#     volumes:
#       - '/:/host:ro,rslave'
# EOF

docker compose -f ~/docker-compose.yml up -d 