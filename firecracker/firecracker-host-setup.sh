#!/bin/bash
set -ex

# Sets up a remote VM (e.g. a GCP instance with nested virtualization enabled)
# to run Firecracker microVMs via `ONCTL_CLOUD=firecracker onctl ...`.

apt-get update
apt-get install -y curl iproute2 e2fsprogs iptables
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

if [ -e /dev/kvm ]; then
  echo "/dev/kvm is available"
else
  echo "WARNING: /dev/kvm not found. Enable nested virtualization on this VM" \
       "(e.g. set gcp.vm.nestedVirtualization: true) before running Firecracker."
fi

ARCH="$(uname -m)"

# Install the firecracker binary.
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest_version=$(basename "$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${release_url}/latest")")
curl -fsSL "${release_url}/download/${latest_version}/firecracker-${latest_version}-${ARCH}.tgz" | tar -xz
mv "release-${latest_version}-${ARCH}/firecracker-${latest_version}-${ARCH}" /usr/local/bin/firecracker
chmod +x /usr/local/bin/firecracker
rm -rf "release-${latest_version}-${ARCH}"

# Download a sample kernel and rootfs image for quick microVM testing.
mkdir -p ~/.onctl/firecracker/images
cd ~/.onctl/firecracker/images

CI_VERSION="v1.10"
kernel_key=$(curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/?prefix=firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-5.10&list-type=2" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-5\.10\.[0-9]+)(?=</Key>)" \
  | sort -V | tail -1)
curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/${kernel_key}" -o vmlinux

rootfs_key=$(curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/?prefix=firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-22.04.ext4&list-type=2" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-22\.04\.ext4)(?=</Key>)" \
  | sort -V | tail -1)
curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/${rootfs_key}" -o rootfs.ext4

# Enable IP forwarding and NAT so microVMs can reach the internet.
HOST_IFACE=$(ip route show default | awk '/default/ {print $5; exit}')

# Persist IP forwarding across reboots
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-firecracker.conf
sysctl -p /etc/sysctl.d/99-firecracker.conf

# NAT: masquerade microVM traffic (any tap+ device) through the host's default interface
iptables -t nat -C POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE

# Allow forwarding for return traffic (established/related connections)
iptables -C FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
  || iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow forwarding from tap devices to the host interface
iptables -C FORWARD -i tap+ -o "${HOST_IFACE}" -j ACCEPT 2>/dev/null \
  || iptables -A FORWARD -i tap+ -o "${HOST_IFACE}" -j ACCEPT

# Persist iptables rules across reboots
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# Install onctl itself so microVMs can be managed from this host.
curl -sLS https://docs.onctl.io/get.sh | bash
install onctl /usr/local/bin/

echo "Firecracker host setup complete."
echo "Run: ONCTL_CLOUD=firecracker onctl init"
echo "Then: ONCTL_CLOUD=firecracker onctl create -n my-microvm"