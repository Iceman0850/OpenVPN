# OpenVPN

# OpenVPN Installation and Configuration Script

This script is designed to automate the installation and configuration of OpenVPN on Ubuntu 22.04. It will install the necessary packages, set up the server and client certificates, configure firewall rules, and generate the client configuration file. Below is a detailed explanation of each section of the script.

## Script Overview

- **Update and Install Packages**: The script updates the package list and installs OpenVPN and EasyRSA.
- **Define Variables**: Paths, server name, client name, and server IP addresses are defined.
- **Setup EasyRSA**: EasyRSA is used to generate the Public Key Infrastructure (PKI).
- **Generate Certificates**: Server and client certificates and keys are generated.
- **Configure OpenVPN Server**: The OpenVPN server configuration is created.
- **Firewall Rules**: Firewall rules are set to allow OpenVPN traffic.
- **Enable IP Forwarding**: IP forwarding is enabled to route traffic through the VPN.
- **Generate Client Configuration**: A client configuration file is generated and placed in the specified directory.

