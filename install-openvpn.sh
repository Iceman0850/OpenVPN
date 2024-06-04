#!/bin/bash

# This script is intended to install openvpn on Ubuntu 22.04. It will install all required packages and build your client OVPN file. This script will also set firewall rules and configure IP tables.
# Please Uncomment and Modify OVPN_SHARE_DIR to where you want the client files to be backed up to
# After Installation setup port forwarding for port 1194

# Exit script on any error
set -e

# Default values
SERVER_NAME=Server
CLIENT_NAME=Client
EASYRSA_DIR=~/easy-rsa
OVPN_CONFIG_DIR=/etc/openvpn
CLIENT_DIR=$OVPN_CONFIG_DIR/client
SERVER_IP="10.8.0.0 255.255.255.0"
CLIENT_CERT_PASSWORD=""

# Replace with your local network IP range
LOCAL_NETWORK="10.0.0.0/24"  

# Uncomment if you want to specify a location to have the client files copied to a backup loacation
# OVPN_SHARE_DIR=~/Backup

# Display default values and prompt user for confirmation
echo "Default values:"
echo "Server Name: $SERVER_NAME"
echo "Client Name: $CLIENT_NAME"
echo "Server IP: $SERVER_IP"
echo "Local Network: $LOCAL_NETWORK"

read -p "Do you want to use the default values? (y/n): " use_defaults

if [[ $use_defaults =~ ^[Yy](es)?$ ]]; then
    echo "Using default values..."
else
    # Prompt user for values or use defaults
    read -p "Enter the server name or press enter to use default [$SERVER_NAME]: " input
    SERVER_NAME=${input:-$SERVER_NAME}

    read -p "Enter the client name or press enter to use default [$CLIENT_NAME]: " input
    CLIENT_NAME=${input:-$CLIENT_NAME}

    read -p "Enter the server IP or press enter to use default [$SERVER_IP]: " input
    SERVER_IP=${input:-$SERVER_IP}

    read -p "Enter the local network or press enter to use default [$LOCAL_NETWORK]: " input
    LOCAL_NETWORK=${input:-$LOCAL_NETWORK}

    read -p "Enter the client certificate password (leave empty for no password): " input
    CLIENT_CERT_PASSWORD=${input:-$CLIENT_CERT_PASSWORD}
fi

# Update and install OpenVPN
apt-get update
apt-get install -y openvpn easy-rsa

# Get public IP (-4 get ip4 remove to get ipv6)
PUBLIC_IP=$(curl -4 -s ifconfig.me)

# Setup EasyRSA
if [ ! -d "$EASYRSA_DIR" ]; then
    make-cadir $EASYRSA_DIR
fi
cd $EASYRSA_DIR
./easyrsa init-pki

# Build the CA
./easyrsa --batch build-ca nopass

# Generate the server certificate and key
./easyrsa --batch gen-req $SERVER_NAME nopass
./easyrsa --batch sign-req server $SERVER_NAME

# Generate the client certificate and key
if [ -z "$CLIENT_CERT_PASSWORD" ]; then
    ./easyrsa --batch gen-req $CLIENT_NAME nopass
else
    echo -n "$CLIENT_CERT_PASSWORD" | ./easyrsa --batch gen-req $CLIENT_NAME
fi
./easyrsa --batch sign-req client $CLIENT_NAME

# Generate Diffie-Hellman parameters
./easyrsa gen-dh

# Generate the ta.key
openvpn --genkey secret ta.key
cp $EASYRSA_DIR/ta.key $OVPN_CONFIG_DIR

# Create the client directory if it doesn't exist
mkdir -p $CLIENT_DIR

# Copy the necessary files
cp pki/ca.crt pki/issued/$SERVER_NAME.crt pki/private/$SERVER_NAME.key pki/dh.pem $OVPN_CONFIG_DIR
cp pki/ca.crt pki/issued/$CLIENT_NAME.crt pki/private/$CLIENT_NAME.key $CLIENT_DIR

# Configure the server
cat > $OVPN_CONFIG_DIR/server.conf <<EOL
port 1194
proto udp
dev tun
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
dh dh.pem
tls-auth ta.key 0
cipher AES-256-CBC
auth SHA256
server $SERVER_IP
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "route $LOCAL_NETWORK"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
comp-lzo
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOL

# Enable IP forwarding
if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
sysctl -p

# Configure firewall rules using iptables
if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o ens18 -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens18 -j MASQUERADE
fi

if ! iptables -C FORWARD -i tun0 -o ens18 -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i tun0 -o ens18 -j ACCEPT
fi

if ! iptables -C FORWARD -i ens18 -o tun0 -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i ens18 -o tun0 -j ACCEPT
fi

# Make firewall rules persistent
apt-get install -y iptables-persistent
netfilter-persistent save

# Start the OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server
systemctl restart openvpn@server

# Generate client configuration
cat > $CLIENT_DIR/$CLIENT_NAME.ovpn <<EOL
client
dev tun
proto udp
remote $PUBLIC_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
key-direction 1
comp-lzo
verb 3
<ca>
$(cat $OVPN_CONFIG_DIR/ca.crt)
</ca>
<cert>
$(cat $CLIENT_DIR/$CLIENT_NAME.crt)
</cert>
<key>
$(cat $CLIENT_DIR/$CLIENT_NAME.key)
</key>
<tls-auth>
$(cat $OVPN_CONFIG_DIR/ta.key)
</tls-auth>
EOL

# Backup client files if OVPN_SHARE_DIR is set and exists
if [ -n "$OVPN_SHARE_DIR" ] && [ -d "$OVPN_SHARE_DIR" ]; then
    cp $CLIENT_DIR/* $OVPN_SHARE_DIR
    echo "Client files have been backed up to $OVPN_SHARE_DIR."
else
    echo "OVPN_SHARE_DIR is not set or does not exist. No files were backed up."
fi

echo "OpenVPN setup is complete. Client files are configured in $CLIENT_DIR."

exit 0
