# Coder deployment

Provision a VM with Docker and the Coder service ready to use:

```
onctl up -n coder -a coder/init.sh
```

The script installs Docker, creates the required users, and enables the `coder` systemd service so the UI is available after boot.
