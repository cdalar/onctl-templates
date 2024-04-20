#!/bin/bash

# Path to the systemd unit file
unit_file="/etc/systemd/system/ollama.service"

# Check if the OLLAMA_HOST line already exists in the [Service] section
if ! grep -q '^Environment="OLLAMA_HOST=0.0.0.0"' "$unit_file"; then
  # Find the last line of the [Service] section and add the OLLAMA_HOST line after it
  sed -i '/^\[Service\]$/!b;:a;n;/^\[/b a; a Environment="OLLAMA_HOST=0.0.0.0"' "$unit_file"
  echo "OLLAMA_HOST line added to the [Service] section."
else
  echo "OLLAMA_HOST line already exists in the [Service] section."
fi

# Reload systemd to apply the changes
systemctl daemon-reload

# Optionally, restart the service to apply the changes
systemctl restart ollama.service
