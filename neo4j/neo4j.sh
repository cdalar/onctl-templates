#!/bin/bash
# Runs Neo4j (https://neo4j.com) Community in Docker, with its data in
# NEO4J_HOME on the VM. Two ports are published, and the Browser needs
# both: 7474 serves the Browser itself, 7687 is Bolt, which the Browser
# opens from your machine to run queries.
#
# Neo4j sets the password only when it creates the database. The script
# keeps the one in use in NEO4J_HOME/password and reuses it on a rerun.
set -euo pipefail

NEO4J_VERSION=${NEO4J_VERSION:-2026.09.0}
NEO4J_HOME=${NEO4J_HOME:-/opt/neo4j}
NEO4J_PASSWORD=${NEO4J_PASSWORD:-}
BOLT_ADVERTISED_ADDRESS=${BOLT_ADVERTISED_ADDRESS:-}

# get.docker.com rather than docker/docker.sh: that one only knows Ubuntu.
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

mkdir -p "$NEO4J_HOME/data" "$NEO4J_HOME/logs"
if [ -f "$NEO4J_HOME/password" ]; then
  if [ -n "$NEO4J_PASSWORD" ] && [ "$NEO4J_PASSWORD" != "$(cat "$NEO4J_HOME/password")" ]; then
    echo "NEO4J_PASSWORD ignored: the database in $NEO4J_HOME/data already has a password ($NEO4J_HOME/password)." >&2
  fi
  NEO4J_PASSWORD=$(cat "$NEO4J_HOME/password")
else
  [ -n "$NEO4J_PASSWORD" ] || NEO4J_PASSWORD=$(openssl rand -hex 12)
  if [ ${#NEO4J_PASSWORD} -lt 8 ]; then
    echo "NEO4J_PASSWORD must be at least 8 characters." >&2
    exit 1
  fi
  (umask 077 && printf '%s\n' "$NEO4J_PASSWORD" >"$NEO4J_HOME/password")
fi

args=()
if [ -n "$BOLT_ADVERTISED_ADDRESS" ]; then
  args+=(-e "NEO4J_server_bolt_advertised__address=$BOLT_ADVERTISED_ADDRESS")
fi

docker rm -f neo4j >/dev/null 2>&1 || true
docker run -d \
  --name neo4j \
  --restart unless-stopped \
  -p 7474:7474 \
  -p 7687:7687 \
  -v "$NEO4J_HOME/data:/data" \
  -v "$NEO4J_HOME/logs:/logs" \
  -e "NEO4J_AUTH=neo4j/$NEO4J_PASSWORD" \
  "${args[@]}" \
  neo4j:"$NEO4J_VERSION"

for _ in $(seq 60); do
  if curl -fs -o /dev/null http://localhost:7474; then
    echo "Neo4j Browser: http://${PUBLIC_IP:-localhost}:7474"
    echo "Bolt:          bolt://${BOLT_ADVERTISED_ADDRESS:-${PUBLIC_IP:-localhost}:7687}"
    echo "User:          neo4j"
    echo "Password:      $NEO4J_PASSWORD"
    exit 0
  fi
  sleep 2
done

echo "Neo4j did not answer on port 7474 within 2 minutes." >&2
docker logs --tail 50 neo4j >&2
exit 1
