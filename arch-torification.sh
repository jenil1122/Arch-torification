#!/bin/bash

display_gui() {

      cleanup() {
    echo -e "\nGoodbye!"
    exit 0
}

trap cleanup SIGINT

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
            cleanup
        fi
    else
        echo
        echo "All dependencies are already installed."
    fi
elif [ "$a" == "n" ]; then
    cleanup
else
    echo "Invalid input. Please enter 'y' or 'n'."
    exit 1
fi

sleep 0.5
clear

display_menu() {
    echo "Options:"
    echo
    echo -e "1. Setup ${G}(needs to be run only once for new installation)${N}"
    echo "2. Start System-wide Tor"
    echo "3. Stop System-wide Tor"
    echo "4. Exit"
    echo
}

restart_network_services() {
    if systemctl status NetworkManager &> /dev/null; then
        echo -e "${G}Restarting NetworkManager service...${N}"
        sudo systemctl restart NetworkManager
    elif systemctl status systemd-networkd &> /dev/null; then
        echo -e "${G}Restarting systemd-networkd service...${N}"
        sudo systemctl restart systemd-networkd
    elif systemctl status connman &> /dev/null; then
        echo -e "${G}Restarting ConnMan service...${N}"
        sudo systemctl restart connman
    elif systemctl status wicd &> /dev/null; then
        echo -e "${G}Restarting Wicd service...${N}"
        sudo systemctl restart wicd
    elif systemctl status netctl &> /dev/null; then
        echo -e "${G}Restarting netctl service...${N}"
        sudo systemctl restart netctl
    elif systemctl status iwd &> /dev/null; then
        echo -e "${G}Restarting iwd service...${N}"
        sudo systemctl restart iwd
    else
        echo "Cannot detect any known network service. Please restart your network manually."
    fi
}


setup_tor_iptables() {
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
    echo -e "${G}Done and Dusted..${N}"

}

while true; do
    display_menu
    read -p "Enter your choice: " choice
    echo # Line spacing

    case $choice in
        1)
            setup_tor_iptables
            echo # Line spacing
            ;;
        2)
            echo -e "${G}Starting SystemTor...${N}"
            sudo systemctl start tor
            echo -e "${G}Starting iptables service...${N}"
            sudo systemctl start iptables
            echo -e "${G}Starting ip6tables service...${N}"
            sudo systemctl start ip6tables
            restart_network_services
            echo # Line spacing
            ;;
        3)
            echo -e "${G}Stopping SystemTor...${N}"
            sudo systemctl stop tor
            echo -e "${G}Stopping iptables service...${N}"
            sudo systemctl stop iptables
            echo -e "${G}Stopping ip6tables service...${N}"
            sudo systemctl stop ip6tables
            restart_network_services
            echo # Line spacing
            ;;
        4)
            cleanup
            echo # Line spacing
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 4."
            echo # Line spacing
            ;;
    esac

done
      
}

G="\e[32m" # Green color
R="\e[31m" # Red color
N="\e[0m"  # Reset color

start_tor() {
    echo -e "${G}Starting SystemTor...${N}"
    sudo systemctl start tor
    echo -e "${G}Starting iptables service...${N}"
    sudo systemctl start iptables
    echo -e "${G}Starting ip6tables service...${N}"
    sudo systemctl start ip6tables
    restart_network_services
    echo # Line spacing
}

stop_tor() {
    echo -e "${G}Stopping SystemTor${N}"
    sudo systemctl stop tor
    echo -e "${G}Stopping iptables service...${N}"
    sudo systemctl stop iptables
    echo -e "${G}Stopping ip6tables service...${N}"
    sudo systemctl stop ip6tables
    restart_network_services
    echo 
}

check_status() {
    echo
    echo -e "${G}Checking status of Tor and related services...${N}"
    echo
    tor_status=$(sudo systemctl is-active tor)
    iptables_status=$(sudo systemctl is-active iptables)
    ip6tables_status=$(sudo systemctl is-active ip6tables)

    if [[ $tor_status == "active" && $iptables_status == "active" && $ip6tables_status == "active" ]]; then
        echo -e "${G}Torification is Enabled System Wide${N}"
    else
        echo -e "${R}Torification is Disabled System Wide${N}"
    fi
    echo
}

restart_network_services() {
    if systemctl status NetworkManager &> /dev/null; then
        echo -e "${G}Restarting NetworkManager service...${N}"
        sudo systemctl restart NetworkManager
    elif systemctl status systemd-networkd &> /dev/null; then
        echo -e "${G}Restarting systemd-networkd service...${N}"
        sudo systemctl restart systemd-networkd
    elif systemctl status connman &> /dev/null; then
        echo -e "${G}Restarting ConnMan service...${N}"
        sudo systemctl restart connman
    elif systemctl status wicd &> /dev/null; then
        echo -e "${G}Restarting Wicd service...${N}"
        sudo systemctl restart wicd
    elif systemctl status netctl &> /dev/null; then
        echo -e "${G}Restarting netctl service...${N}"
        sudo systemctl restart netctl
    elif systemctl status iwd &> /dev/null; then
        echo -e "${G}Restarting iwd service...${N}"
        sudo systemctl restart iwd
    else
        echo "Cannot detect any known network service. Please restart your network manually."
    fi
}

setup() {

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
    echo -e "${G}Done and Dusted..${N}"   

}

handle_options() {
    case "$1" in
        "--setup")
            setup
            ;;
        "--start-tor")
            start_tor
            ;;
        "--stop-tor")
            stop_tor
            ;;
        "--status")
            check_status
            ;;
        "--help")
            display_help
            ;;
        *)
            echo "Invalid option. Use '--help' for usage instructions."
            exit 1
            ;;
    esac
}

display_help() {
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  --setup       Required To Do only Once"
    echo "  --start-tor   Start Tor and related services"
    echo "  --stop-tor    Stop Tor and related services"
    echo "  --status      Check status of Tor and related services"
    echo "  --help        Display this help message"
    echo
}

if [ "$#" -eq 0 ]; then
    display_gui
else
    handle_options "$1"
fi
