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

On a box (boxctl.io) the VM has no public address; each port gets its own HTTPS URL instead. Expose two ports, not
one:

```
boxctl expose graph 7474     # https://graph-aaaaaaaa.boxctl.app -> the Browser
boxctl expose graph 7687     # https://graph-bbbbbbbb.boxctl.app -> Bolt
boxctl expose graph          # list both URLs
```

Open the URL of port 7474 and fill in the connect form:

| Field          | Value                                                                    |
| -------------- | ------------------------------------------------------------------------ |
| Protocol       | `bolt+s://`                                                              |
| Connection URL | the host of the port **7687** URL, then `:443`: `graph-bbbbbbbb.boxctl.app:443` |
| Database       | leave empty (the default database, `neo4j`)                              |
| Username       | `neo4j`                                                                  |
| Password       | printed by the script; `cat /opt/neo4j/password` on the VM               |

Three things go wrong here:

- The Browser fills in the host of the page with port `7687`, e.g. `graph-aaaaaaaa.boxctl.app:7687`. Nothing listens
  there. Replace it with the host of the other URL, the one for port 7687.
- The port is `443`, not `7687`: you are connecting to the HTTPS URL, which forwards to 7687 on the VM.
- `bolt://` and `neo4j://` are refused. A page served over HTTPS may only open encrypted connections, so the protocol
  has to end in `+s`. Leave `https://` out of the connection URL.

Neo4j itself needs no certificate. Bolt on 7687 also speaks WebSocket, which is what the Browser uses, and the URL
passes WebSockets through with its own TLS.

To have the Browser fill in the right address by itself, and to make `neo4j+s://` work too, tell Neo4j where Bolt
is reachable. This restarts the container and keeps the data and the password:

```
boxctl ssh graph -T 3m -- "curl -fsSL https://templates.onctl.com/neo4j/neo4j.sh | BOLT_ADVERTISED_ADDRESS=graph-bbbbbbbb.boxctl.app:443 bash"
```

Keep both ports exposed once they are set up. A URL stays the same for as long as its port is exposed, across pause
and resume, but `boxctl unexpose` retires it: exposing the port again gives a new one. After that, the address in
the connect form and `BOLT_ADVERTISED_ADDRESS` both have to be changed to the new 7687 URL.

Anyone who has the URLs can reach the database; the password is all that protects it.

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
