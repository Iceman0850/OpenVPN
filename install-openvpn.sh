#!/bin/bash

# This script is intended to install openvpn on Ubuntu 22.04. It will install all required packages and build your client cert. This script will also set firewall rules.
# Please Modify OVPN_SHARE_DIR to where you want the client files to be backed up to
# After Installation setup port forwarding for port 1194

# you can customize SERVER_NAME and CLIENT_NAME 

# Exit script on any error
set -e

# Define paths
EASYRSA_DIR=~/easy-rsa
OVPN_CONFIG_DIR=/etc/openvpn
CLIENT_DIR=$OVPN_CONFIG_DIR/client

# Uncomment and set OVPN_SHARE_DIR to create a backup copy of the client files
#OVPN_SHARE_DIR=~/backup

# Define client and server names
SERVER_NAME=Server
CLIENT_NAME=Client

# Define serve IPs
SERVER_IP="10.8.0.0 255.255.255.0"

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
./easyrsa --batch gen-req $CLIENT_NAME nopass
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
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure firewall
apt install -y ufw
ufw allow 1194/udp

# Reset the firewall rules
ufw disable
ufw enable

# Uncomment the following line if you are accessing the server via SSH and want to ensure you don't lock yourself out
#ufw allow OpenSSH

# Start the OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server

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
