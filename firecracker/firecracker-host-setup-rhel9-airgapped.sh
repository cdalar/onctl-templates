#!/bin/bash
set -ex

# RHEL 9 / air-gapped variant of firecracker-host-setup.sh: sets up a
# KVM-capable host to run Firecracker microVMs via `ONCTL_CLOUD=fc onctl ...`
# without downloading anything. Run it as root on the host itself.
#
# On a connected machine, download the four files it needs and copy them
# into one directory on the host:
#
#   ARCH=x86_64 ONCTL_ARCH=amd64     # for an ARM host: ARCH=aarch64 ONCTL_ARCH=arm64
#   FC=v1.18.0                       # any firecracker release tag
#   curl -fLO "https://github.com/cdalar/onctl/releases/latest/download/onctl-linux-${ONCTL_ARCH}.tar.gz"
#   curl -fLO "https://github.com/firecracker-microvm/firecracker/releases/download/${FC}/firecracker-${FC}-${ARCH}.tgz"
#   curl -fLO "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${ARCH}/vmlinux-5.10.223"
#   curl -fLO "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${ARCH}/ubuntu-22.04.ext4"
#
# Then: sudo BUNDLE_DIR=/path/to/that/directory ./firecracker-host-setup-rhel9-airgapped.sh

BUNDLE_DIR="${BUNDLE_DIR:-$PWD}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root (the fc provider needs root for its bridge/TAP devices)." >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ONCTL_ARCH=amd64 ;;
  aarch64) ONCTL_ARCH=arm64 ;;
  *) echo "ERROR: unsupported architecture ${ARCH}" >&2; exit 1 ;;
esac

# pick <glob>: the newest file in BUNDLE_DIR matching the glob, or fail.
pick() {
  local f
  f=$(compgen -G "${BUNDLE_DIR}/$1" | sort -V | tail -1)
  if [ -z "$f" ]; then
    echo "ERROR: no file matching '$1' in ${BUNDLE_DIR}" >&2
    exit 1
  fi
  echo "$f"
}

# Resolve every file up front, so a missing one fails before anything is installed.
onctl_tgz=$(pick "onctl-linux-${ONCTL_ARCH}.tar.gz")
firecracker_tgz=$(pick "firecracker-v*-${ARCH}.tgz")
kernel=$(pick "vmlinux-[0-9]*[0-9]")   # ends in a digit: skips the .config and -no-acpi variants
rootfs=$(pick "ubuntu-*.ext4")

# Packages come from whatever repository the host can reach (an internal
# mirror or the installation media); there is nothing to fall back to.
missing=()
for pkg in iproute e2fsprogs tar gzip; do
  rpm -q "$pkg" >/dev/null || missing+=("$pkg")
done
if [ "${#missing[@]}" -gt 0 ]; then
  dnf install -y "${missing[@]}"
fi

if [ ! -e /dev/kvm ]; then
  modprobe kvm_intel 2>/dev/null || modprobe kvm_amd 2>/dev/null || true
fi
if [ -e /dev/kvm ]; then
  echo "/dev/kvm is available"
else
  echo "WARNING: /dev/kvm not found. Enable (nested) virtualization for this host" \
       "before running Firecracker."
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Install the firecracker binary.
release=$(basename "$firecracker_tgz" .tgz)            # firecracker-v1.18.0-x86_64
tar -xzf "$firecracker_tgz" -C "$workdir"
install -m 0755 "${workdir}/release-${release#firecracker-}/${release}" /usr/local/bin/firecracker

# Install onctl itself so microVMs can be managed from this host.
tar -xzf "$onctl_tgz" -C "$workdir" onctl
install -m 0755 "${workdir}/onctl" /usr/local/bin/onctl

# Kernel and rootfs image, where the fc provider looks by default.
mkdir -p ~/.onctl/firecracker/images
cp "$kernel" ~/.onctl/firecracker/images/vmlinux
cp "$rootfs" ~/.onctl/firecracker/images/rootfs.ext4

echo "Firecracker host setup complete."
echo "Run: sudo ONCTL_CLOUD=fc onctl create -n my-microvm"
