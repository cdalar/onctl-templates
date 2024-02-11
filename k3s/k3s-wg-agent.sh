#!/bin/bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --server https://${SERVER_IP}:6443 --node-external-ip=${PUBLIC_IP} --token ${TOKEN}" sh -s -