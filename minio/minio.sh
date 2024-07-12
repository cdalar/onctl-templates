#!/bin/bash
wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20240710184149.0.0_amd64.deb -O minio.deb
sudo dpkg -i minio.deb

groupadd -r minio-user
useradd -M -r -g minio-user minio-user
chown minio-user:minio-user /mnt

cat <<EOF > /etc/default/minio
# Set the hosts and volumes MinIO uses at startup
# The command uses MinIO expansion notation {x...y} to denote a
# sequential series.
#
# The following example covers four MinIO hosts
# with 4 drives each at the specified hostname and drive locations.
# The command includes the port that each MinIO server listens on
# (default 9000)

MINIO_VOLUMES="/mnt"

# Set all MinIO server options
#
# The following explicitly sets the MinIO Console listen address to
# port 9001 on all network interfaces. The default behavior is dynamic
# port selection.

MINIO_OPTS="--console-address :9001"

# Set the root username. This user has unrestricted permissions to
# perform S3 and administrative API operations on any resource in the
# deployment.
#
# Defer to your organizations requirements for superadmin user name.

MINIO_ROOT_USER=admin

# Set the root password
#
# Use a long, random, unique string that meets your organizations
# requirements for passwords.

MINIO_ROOT_PASSWORD=adminpassword
EOF

systemctl enable --now minio.service # Start MinIO service

