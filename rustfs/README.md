# RustFS on Docker

This template deploys [RustFS](https://rustfs.com/) using the official Docker image. It installs Docker when required, prepares data/log directories with the correct UID for the container (10001), and runs RustFS with ports 9000 (S3 API) and 9001 (console) exposed.

## Usage

```bash
# Optional: set a specific version and custom data/log paths
export RUSTFS_VERSION=1.0.0-alpha.76
export DATA_DIR=/opt/rustfs/data
export LOG_DIR=/opt/rustfs/logs

# Run the installer
./rustfs.sh
```

The container is started with `--restart unless-stopped`. If an existing `rustfs` container is found it will be replaced so new configuration takes effect.
