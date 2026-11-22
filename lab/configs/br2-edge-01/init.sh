#!/bin/sh
# br2-edge-01 start-up: VLAN 99 placeholder interface and GUEST-IN.
set -eu
. /cnops/common.sh

# VLAN 99 MGMT has no hosts in the lab; a dummy interface keeps the subnet
# up and advertised, like an SVI that is "up/up".
ip link add mgmt99 type dummy 2>/dev/null || true
ip link set mgmt99 up

add_guest_in eth4 10.30.30.0/24
