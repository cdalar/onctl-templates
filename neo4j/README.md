## Neo4j

Runs [Neo4j](https://neo4j.com) Community in Docker, with its data kept on the VM in `/opt/neo4j`.

```
onctl up -n graph -a neo4j/neo4j.sh
```

The script installs Docker if the VM doesn't have it, starts the container, waits until Neo4j answers and prints the
address, the user (`neo4j`) and the password. Without `NEO4J_PASSWORD` it generates one. Either way the password is
kept in `/opt/neo4j/password`, readable by root only.

Give the VM 2 GB of memory or more.

### Ports

| Port   | What                                             |
| ------ | ------------------------------------------------ |
| `7474` | HTTP: the Neo4j Browser (the dashboard), and the HTTP query API |
| `7687` | Bolt: what the Browser, drivers and `cypher-shell` talk to     |

The Browser needs both. Port 7474 only delivers the web app; the app then opens its own Bolt connection from your
machine to port 7687 to log in and run queries. With only 7474 reachable the page loads and the login fails.

### Behind public HTTPS URLs

When the VM has no public address and each port gets its own HTTPS URL, expose `7474` and `7687`:

1. Open the URL of port 7474. That is the Browser.
2. In its connect form, pick the `bolt+s://` scheme and enter the host of the port 7687 URL with port `443`,
   e.g. `bolt+s://graph-7687.example.com:443`. Log in as `neo4j`.

A page served over HTTPS may only open encrypted connections, hence `bolt+s://`. Bolt on 7687 also speaks WebSocket,
which is what the Browser uses, so an HTTPS proxy that passes WebSockets through is enough; Neo4j itself needs no
certificate.

To have the Browser fill that address in by itself, and to make the `neo4j+s://` scheme work too, tell Neo4j where
Bolt is reachable:

```
onctl ssh graph -a neo4j/neo4j.sh -e BOLT_ADVERTISED_ADDRESS=graph-7687.example.com:443
```

Drivers and `cypher-shell` on your own machine speak plain TCP Bolt, not WebSocket, so they can't go through an HTTP
URL. Forward the port instead, `onctl port-forward graph 7687`, and use `bolt://localhost:7687`.

### Running it again

Running the script again replaces the container and keeps the data. Neo4j sets the password only when it creates the
database, so a later `NEO4J_PASSWORD` is ignored: the script says so and keeps using the one in `/opt/neo4j/password`.
To change it, run `ALTER CURRENT USER SET PASSWORD FROM '<old>' TO '<new>'` in the Browser and update that file.

### Options

```
onctl up -n graph -a neo4j/neo4j.sh \
  -e NEO4J_PASSWORD=a-long-password \
  -e NEO4J_VERSION=5.26 \
  -e NEO4J_HOME=/mnt/neo4j
```

`NEO4J_VERSION` is an image tag of [`neo4j`](https://hub.docker.com/_/neo4j) on Docker Hub. Add `-enterprise` for
the Enterprise edition, which also needs its licence accepted and isn't set up by this script.
