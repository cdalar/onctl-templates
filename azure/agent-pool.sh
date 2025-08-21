 #!/bin/bash
# Create user ubuntu if needed 
set -ex
if ! id -u ubuntu > /dev/null 2>&1; then
    sudo useradd -m ubuntu -s /bin/bash
fi
sudo -i -u ubuntu bash << EOF
pwd
mkdir -p myagent && cd myagent
wget -q https://download.agent.dev.azure.com/agent/4.260.0/vsts-agent-linux-x64-4.260.0.tar.gz
tar zxf vsts-agent-linux-x64-4.260.0.tar.gz
EOF
cd /home/ubuntu/myagent
# Install dependencies
sudo ./bin/installdependencies.sh > /dev/null
# AGENT_NAME=$(cat /dev/urandom | tr -dc '0-9' | fold -w 5 | head -n 1)
AGENT_NAME=${AGENT_NAME:-$(hostname)} # Default to hostname if AGENT_NAME is not set
sudo -i -u ubuntu bash << EOF
cd myagent
pwd
./config.sh --replace --unattended --url $URL --auth pat --token $TOKEN --pool $AGENT_POOL_NAME --agent $AGENT_NAME --acceptTeeEula
EOF
cd /home/ubuntu/myagent
sudo ./svc.sh install ubuntu
cd /home/ubuntu
set -f; sudo systemctl start -a vsts*; set +f 

## Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
