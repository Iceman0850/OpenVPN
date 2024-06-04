# OpenVPN

# OpenVPN Installation and Configuration Script

This script is designed to automate the installation and configuration of OpenVPN on Ubuntu 22.04. It will install the necessary packages, set up the server and client certificates, configure firewall rules, and generate the client configuration file. Below is a detailed explanation of each section of the script.

Script Overview
1. Update and Install Packages
The script begins by updating the package list and installing the required packages: OpenVPN and EasyRSA.

2. Define Variables
Paths, server name, client name, and server IP addresses are defined. These variables include:

EASYRSA_DIR: Directory for EasyRSA setup
OVPN_CONFIG_DIR: Directory for OpenVPN configuration
OVPN_SHARE_DIR: Optional directory for client files backup (uncomment if needed)
CLIENT_DIR: Directory for client configuration
SERVER_NAME: Name of the server
CLIENT_NAME: Name of the client
SERVER_IP: IP address range for the server
LOCAL_NETWORK: Local network IP range
CLIENT_CERT_PASSWORD: Password for client certificate (optional)
3. Setup EasyRSA
EasyRSA is used to generate the Public Key Infrastructure (PKI). If the EasyRSA directory does not exist, it is created, and the PKI is initialized.

4. Generate Certificates
The script generates the following certificates and keys:

Certificate Authority (CA)
Server certificate and key
Client certificate and key
Diffie-Hellman parameters
TLS-auth key
5. Configure OpenVPN Server
The OpenVPN server configuration file is created with the necessary settings, including port, protocol, device type, certificates, and keys. The configuration also includes settings for IP pool, routes, DNS, and other parameters to ensure the VPN functions correctly.

6. Firewall Rules
Firewall rules are configured using iptables to allow OpenVPN traffic. NAT and forwarding rules are set to route the traffic from the VPN through the server's network interface.

7. Enable IP Forwarding
IP forwarding is enabled in the system to allow traffic to pass through the VPN server.

8. Generate Client Configuration
A client configuration file is generated and placed in the specified directory. This file includes all the necessary information and certificates for the client to connect to the OpenVPN server.

9. Optional Backup
If OVPN_SHARE_DIR is uncommented and set, the client files are backed up to the specified directory.

