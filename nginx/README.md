# Nginx installation

Bring up a VM with Nginx installed and enabled:

```
onctl up -n nginx -a nginx/install.sh
```

The script updates apt packages, installs Nginx, and ensures the service starts on boot.
