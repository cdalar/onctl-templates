#!/bin/bash
curl -L https://coder.com/install.sh | sh

sudo systemctl enable --now coder
journalctl -u coder.service -b
