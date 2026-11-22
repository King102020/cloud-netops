#!/bin/sh
# hq-edge-01 start-up: NAT/PAT towards the ISP (docs/network-design.md §8).
set -eu
. /cnops/common.sh

# ACL NAT-INSIDE + "ip nat inside source list NAT-INSIDE interface eth1 overload"
for net in 10.10.0.0/16 10.20.0.0/16 10.30.0.0/16; do
  iptables -t nat -A POSTROUTING -o eth1 -s "$net" \
    -m comment --comment "NAT-INSIDE $net" -j MASQUERADE
done
