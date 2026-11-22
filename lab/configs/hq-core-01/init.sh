#!/bin/sh
# hq-core-01 start-up: VLAN 20 bridge (the SVI), GUEST-IN and TO-SERVERS ACLs.
set -eu
. /cnops/common.sh

# VLAN 20 SERVERS: bridge eth5 (hq-srv-01) and eth8 (hq-srv-02) and put the
# gateway address on the bridge, like an SVI on the 3650.
ip link add br20 type bridge 2>/dev/null || true
ip link set eth5 master br20
ip link set eth8 master br20
ip link set br20 up

add_guest_in eth6 10.10.30.0/24

# ACL TO-SERVERS (docs/network-design.md §6.2), outbound on the VLAN 20 SVI.
USERS="10.10.10.0/24 10.20.10.0/24 10.30.10.0/24"
MGMT="10.10.99.0/27 10.20.99.0/27 10.30.99.0/27"
iptables -N TO-SERVERS
# Lines 70/80 (replies to what the servers started): stateful match.
iptables -A TO-SERVERS -m conntrack --ctstate ESTABLISHED,RELATED \
  -m comment --comment "70-80 replies" -j ACCEPT
iptables -A TO-SERVERS -p udp -s 10.0.0.0/8 -d 10.10.20.10 --dport 53 \
  -m comment --comment "10 internal DNS" -j ACCEPT
iptables -A TO-SERVERS -p tcp -s 10.0.0.0/8 -d 10.10.20.10 --dport 53 \
  -m comment --comment "20 DNS over TCP" -j ACCEPT
for u in $USERS; do
  iptables -A TO-SERVERS -p tcp -s "$u" -d 10.10.20.10 --dport 80 \
    -m comment --comment "30 intranet web" -j ACCEPT
  iptables -A TO-SERVERS -p tcp -s "$u" -d 10.10.20.10 --dport 443 \
    -m comment --comment "40 intranet web TLS" -j ACCEPT
  iptables -A TO-SERVERS -p tcp -s "$u" -d 10.10.20.11 --dport 445 \
    -m comment --comment "50 file shares" -j ACCEPT
done
iptables -A TO-SERVERS -p icmp --icmp-type echo-request -s 10.0.0.0/8 \
  -d 10.10.20.0/24 -m comment --comment "60 ping, internal only" -j ACCEPT
for m in $MGMT; do
  iptables -A TO-SERVERS -p tcp -s "$m" -d 10.10.20.0/24 --dport 22 \
    -m comment --comment "90 admin SSH from MGMT" -j ACCEPT
done
iptables -A TO-SERVERS -m comment --comment "100 default deny" -j DROP
iptables -A FORWARD -o br20 -j TO-SERVERS
