#!/bin/sh
# Shared start-up steps for every cnops lab router (sourced by each init.sh).

# 1. Drop the Docker management default route (eth0), so the OSPF or static
#    default route is the one the kernel uses. Management stays reachable
#    through `docker exec`.
ip route del default dev eth0 2>/dev/null || true

# 2. Route between interfaces.
sysctl -qw net.ipv4.ip_forward=1

# 3. Asymmetric paths are normal while OSPF reconverges; do not drop them.
sysctl -qw net.ipv4.conf.all.rp_filter=0
sysctl -qw net.ipv4.conf.default.rp_filter=0

# add_guest_in <iface> <guest-subnet>
# ACL GUEST-IN (docs/network-design.md §6.1). Applied to traffic arriving on
# the guest interface, both routed through and addressed to the router,
# like an inbound IOS ACL. DHCP (line 10) is not needed: lab hosts are static.
add_guest_in() {
  iptables -N GUEST-IN
  iptables -A GUEST-IN -d 10.0.0.0/8 -m comment --comment "20 nothing internal" -j DROP
  iptables -A GUEST-IN -d 172.16.0.0/12 -m comment --comment "30 RFC 1918" -j DROP
  iptables -A GUEST-IN -d 192.168.0.0/16 -m comment --comment "40 RFC 1918" -j DROP
  iptables -A GUEST-IN -s "$2" -m comment --comment "50 internet only, anti-spoofing" -j ACCEPT
  iptables -A GUEST-IN -m comment --comment "60 default deny" -j DROP
  iptables -A FORWARD -i "$1" -j GUEST-IN
  iptables -A INPUT -i "$1" -j GUEST-IN
}
