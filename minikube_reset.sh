#!/bin/sh

function minikube_reset_vbox_dhcp_leases() {
  # # Reset Virtualbox DHCP Lease Info
  echo "Resetting Virtualbox DHCP Lease Info..."
  kill -9 $(ps aux |grep -i "vboxsvc\|vboxnetdhcp" | awk '{print $2}') 2>/dev/null

  if [[ -f ~/Library/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.leases ]] ; then
    rm  ~/Library/VirtualBox/HostInterfaceNetworking-vboxnet0-Dhcpd.leases
  fi
}

minikube_reset_vbox_dhcp_leases