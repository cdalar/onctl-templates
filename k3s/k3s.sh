#!/bin/bash
onctl up -n k3s-server -a k3s/k3s-wg-server.sh -d /tmp/token -d /tmp/k3s.yaml
SERVER_IP=$(onctl ls -ojson | jq -r '.[] | select(.Name == "k3s-server") | .IP')

# Environment variable that determines the number of times to run the command
NODE_COUNT=${NODE_COUNT:-2}  # Default to 2 times if N is not set

# Loop to run the command N times
for ((i = 1; i <= NODE_COUNT; i++)); do
    NODE_NAME="k3s-node$i"
    nohup onctl up -n $NODE_NAME -a k3s/k3s-wg-agent.sh \
        -e SERVER_IP="$SERVER_IP" \
        -e TOKEN="$(cat token)" &
done
