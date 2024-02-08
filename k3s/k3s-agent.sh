#!/bin/bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --server https://${SERVER_IP}:6443 --token 123456" sh -s -