# Cloudflare

## Environment Variables

- `CF_TOKEN`: The Cloudflare Tunnel token

## Install cloudflared and create a tunnel for the domain

```
onctl ssh cf-tunnel \
    -a cloudflare/tunnel.sh \
    -e CF_TOKEN=eyXXXX
```
