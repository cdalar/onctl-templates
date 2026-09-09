#!/bin/bash
set -ex

# Sets up a remote host to run Cloud Hypervisor microVMs via
# `ONCTL_CLOUD=ch onctl ...`, including the extra host packages the Windows
# guest path (--ch-os windows) needs on top of the base Linux ch path:
#   - genisoimage: builds the NoCloud/config-drive seed ISO cloud-init and
#     cloudbase-init read hostname/SSH-key config from.
#   - dnsmasq: DHCP for Windows guests (the Linux ch path configures
#     networking via a kernel ip= cmdline argument instead and doesn't need
#     this).
# See https://github.com/cdalar/onctl/blob/main/TESTING-ch-windows.md for
# the full Windows base-image prep recipe -- this script only prepares the
# *host*; a Windows base image (windows.raw) is a separate, much larger
# artifact this script does not build or download.

apt-get update
apt-get install -y curl iproute2 genisoimage dnsmasq

if [ -e /dev/kvm ]; then
  echo "/dev/kvm is available"
else
  echo "WARNING: /dev/kvm not found. Enable nested virtualization on this VM" \
       "before running Cloud Hypervisor."
fi

# Install the cloud-hypervisor binary.
curl -fsSL https://github.com/cloud-hypervisor/cloud-hypervisor/releases/latest/download/cloud-hypervisor-static \
  -o /usr/local/bin/cloud-hypervisor
chmod +x /usr/local/bin/cloud-hypervisor

mkdir -p ~/.onctl/cloud-hypervisor/images
cd ~/.onctl/cloud-hypervisor/images

# UEFI firmware -- required for --ch-os windows (Windows has no
# direct-kernel-boot path the way Linux does).
curl -fsSL https://github.com/cloud-hypervisor/edk2/releases/latest/download/CLOUDHV.fd -o CLOUDHV.fd

# Install onctl itself so microVMs can be managed from this host.
curl -fsSL https://onctl.sh/get.sh | bash
install onctl /usr/local/bin/

echo "Cloud Hypervisor host setup complete."
echo
echo "Linux guests need a kernel (vmlinux, built with virtio-pci support --"
echo "a Firecracker vmlinux will NOT work here, see TESTING-ch-windows.md) and"
echo "an ext4 rootfs:"
echo "  ONCTL_CLOUD=ch onctl create -n my-microvm \\"
echo "    --ch-kernel-image <vmlinux> --ch-rootfs-image <rootfs.ext4>"
echo
echo "Windows guests need a pre-built, syspreped base image -- see"
echo "https://github.com/cdalar/onctl/blob/main/TESTING-ch-windows.md"
echo "  ONCTL_CLOUD=ch onctl create -n my-windows-vm --ch-os windows \\"
echo "    --ch-kernel-image ~/.onctl/cloud-hypervisor/images/CLOUDHV.fd \\"
echo "    --ch-rootfs-image <windows.raw> --username Administrator"
