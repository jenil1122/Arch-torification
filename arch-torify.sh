#!/bin/bash

clear

R='\033[0;31m'
G='\033[0;32m'
N='\033[0m'

echo "Welcome!"
echo "Following packages will be installed if not yet installed:"
echo
echo "1. Tor"
echo "2. iptables"
echo
read -p "Press 'y' to continue or 'n' to exit: " a

if [ "$a" == "y" ]; then
    echo "Checking for dependencies..."
    echo
    mp=""

    if ! command -v tor &> /dev/null; then
        echo -e "${R}Tor is not installed.${N}"
        mp+="tor "
    else
        echo -e "${G}Tor is installed.${N}"
    fi

    if ! command -v iptables &> /dev/null; then
        echo -e "${R}Iptables is not installed.${N}"
        mp+="iptables "
    else
        echo -e "${G}Iptables is installed.${N}"
    fi

    if [ -n "$mp" ]; then
        read -p "Do you want to install missing packages? (y/n): " ia
        if [ "$ia" == "y" ]; then
            echo "Installing missing packages..."
            sudo pacman -S $mp
        else
            echo "Exiting without installing missing packages."
            exit 0
        fi
    else
        echo   
        echo "All dependencies are already installed."
    fi
elif [ "$a" == "n" ]; then
    echo "Goodbye!"
    exit 0
else
    echo "Invalid input. Please enter 'y' or 'n'."
    exit 1
fi

if [ -d "/etc/iptables" ]; then
    echo "Removing existing files in /etc/iptables directory..."
    sudo rm -rf /etc/iptables/*
else
    echo "Creating /etc/iptables directory..."
    sudo mkdir -p /etc/iptables
fi

sudo tee /etc/iptables/iptables.rules /etc/iptables/ip6tables.rules > /dev/null <<EOF
*nat
:PREROUTING ACCEPT [6:2126]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [17:6239]
:POSTROUTING ACCEPT [6:408]

-A PREROUTING ! -i lo -p udp -m udp --dport 53 -j REDIRECT --to-ports 5353
-A PREROUTING ! -i lo -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9040
-A OUTPUT -o lo -j RETURN
--ipv4 -A OUTPUT -d 192.168.0.0/16 -j RETURN
-A OUTPUT -m owner --uid-owner "tor" -j RETURN
-A OUTPUT -p udp -m udp --dport 53 -j REDIRECT --to-ports 5353
-A OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9040
COMMIT

*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT DROP [0:0]

-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
--ipv4 -A INPUT -p tcp -j REJECT --reject-with tcp-reset
--ipv4 -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
--ipv4 -A INPUT -j REJECT --reject-with icmp-proto-unreachable
--ipv6 -A INPUT -j REJECT
--ipv4 -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
--ipv4 -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
--ipv6 -A OUTPUT -d ::1/8 -j ACCEPT
-A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A OUTPUT -m owner --uid-owner "tor" -j ACCEPT
--ipv4 -A OUTPUT -j REJECT --reject-with icmp-port-unreachable
--ipv6 -A OUTPUT -j REJECT
COMMIT
EOF

sudo sed -i 's/:OUTPUT -d 127.0.0.0\/8 -j ACCEPT/:OUTPUT -d 127.0.0.0\/128 -j ACCEPT\n-A OUTPUT -d ::1\/128 -j ACCEPT\n-A OUTPUT -d fe80::\/10 -j ACCEPT/' /etc/iptables/ip6tables.rules

echo "Files iptables.rules and ip6tables.rules have been created and modified in /etc/iptables directory."

sudo sed -i '/^\s*#.*SOCKSPort 9050/s/^#//' /etc/tor/torrc
sudo sed -i '/^\s*#.*DNSPort 5353/s/^#//' /etc/tor/torrc
sudo sed -i '/^\s*#.*TransPort 9040/s/^#//' /etc/tor/torrc

if ! grep -q "SOCKSPort 9050" /etc/tor/torrc; then
    echo "" | sudo tee -a /etc/tor/torrc > /dev/null
    echo "SOCKSPort 9050" | sudo tee -a /etc/tor/torrc > /dev/null
fi

if ! grep -q "DNSPort 5353" /etc/tor/torrc; then
    echo "DNSPort 5353" | sudo tee -a /etc/tor/torrc > /dev/null
fi

if ! grep -q "TransPort 9040" /etc/tor/torrc; then
    echo "TransPort 9040" | sudo tee -a /etc/tor/torrc > /dev/null
fi

echo "Configuration added to /etc/tor/torrc file."

sleep 1.5

clear


#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display Tor options
display_tor_options() {
    echo "Tor Options:"
    echo
    echo "1. Start System wide Tor"
    echo "2. Stop System wide Tor"
    echo "3. Exit"
    echo
}

# Function to restart network services
restart_network_services() {
    if systemctl status NetworkManager &> /dev/null; then
        echo -e "${GREEN}Restarting NetworkManager service...${NC}"
        sudo systemctl restart NetworkManager
    else
        echo "Cannot detect NetworkManager service. Please restart your network manually."
    fi
}

# Display Tor options and get user choice
display_tor_options
read -p "Enter your choice: " tc

# Handle user choice
case $tc in
    1)
        echo -e "${GREEN}Starting SystemTor...${NC}"
        sudo systemctl start tor
        echo -e "${GREEN}Starting iptables service...${NC}"
        sudo systemctl start iptables
        echo -e "${GREEN}Starting ip6tables service...${NC}"
        sudo systemctl start ip6tables
        restart_network_services
        ;;
    2)
        echo -e "${GREEN}Stopping SystemTor...${NC}"
        sudo systemctl stop tor
        echo -e "${GREEN}Stopping iptables service...${NC}"
        sudo systemctl stop iptables
        echo -e "${GREEN}Stopping ip6tables service...${NC}"
        sudo systemctl stop ip6tables
        restart_network_services
        ;;
    3)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
