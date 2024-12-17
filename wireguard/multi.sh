#!/bin/bash
# Set NUM_OF_CLIENTS for more then 1 client
# OS: Ubuntu 22.04 LTS
set -ex

# Update and install dependencies
apt update
apt install -y wireguard qrencode nftables nginx net-tools

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Disable and stop systemd-resolved
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved 
rm /etc/resolv.conf

# Set up DNS resolver
cat > /etc/resolv.conf <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
EOL

# Generate server private/public keys
wg genkey | tee /etc/wireguard/private.key
chmod go= /etc/wireguard/private.key
cat /etc/wireguard/private.key | wg pubkey | tee /etc/wireguard/public.key

# Generate WireGuard server config
cat > /etc/wireguard/wg0.conf <<EOL
# WireGuard Server Configuration
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
ListenPort = 51820

# Enable NAT using nftables
PostUp = nft add table ip wireguard; nft add chain ip wireguard wireguard_chain {type nat hook postrouting priority srcnat\; policy accept\;}; nft add rule ip wireguard wireguard_chain counter packets 0 bytes 0 masquerade; nft add table ip6 wireguard; nft add chain ip6 wireguard wireguard_chain {type nat hook postrouting priority srcnat\; policy accept\;}; nft add rule ip6 wireguard wireguard_chain counter packets 0 bytes 0 masquerade
PostDown = nft delete table ip wireguard; nft delete table ip6 wireguard

# Client peer configurations will be added here dynamically
EOL

# Set number of clients from environment variable or default to 1
CLIENT_COUNT=${NUM_OF_CLIENTS:-1}
echo "Configuring ${CLIENT_COUNT} clients..."

# Add multiple users
for i in $(seq 1 $CLIENT_COUNT); do
    CLIENT_KEY_PATH=/etc/wireguard/client${i}_private.key
    CLIENT_PUB_PATH=/etc/wireguard/client${i}_public.key

    # Generate unique client keypair
    wg genkey | tee ${CLIENT_KEY_PATH} | wg pubkey | tee ${CLIENT_PUB_PATH}

    CLIENT_IP="192.168.2.$((i+1))/32"

    # Append client to server config
    cat >> /etc/wireguard/wg0.conf <<EOL
[Peer]
PublicKey = $(cat ${CLIENT_PUB_PATH})
AllowedIPs = ${CLIENT_IP}
EOL

    # Generate client configuration file
    CLIENT_CONFIG=~/wg-client${i}.conf
    cat > ${CLIENT_CONFIG} <<EOL
[Interface]
PrivateKey = $(cat ${CLIENT_KEY_PATH})
Address = ${CLIENT_IP}
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/public.key)
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $PUBLIC_IP:51820
PersistentKeepalive = 25
EOL

    # Generate QR code and copy client config to web server root
    qrencode -t png -o /var/www/html/qr-client${i}.png < ${CLIENT_CONFIG}
    cp ${CLIENT_CONFIG} /var/www/html/wg-client${i}.conf

done

# Enable WireGuard
wg-quick up wg0
wg show

# Restart NGINX
systemctl restart nginx

echo "WireGuard server setup complete with ${CLIENT_COUNT} clients."
