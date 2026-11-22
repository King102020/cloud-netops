# FRR plus iptables, so lab routers can enforce the ACLs from
# docs/network-design.md section 6 (FRR itself does not filter packets).
FROM quay.io/frrouting/frr:10.2.1

RUN apk add --no-cache iptables tcpdump

LABEL org.opencontainers.image.title="cnops-frr" \
      org.opencontainers.image.description="FRR 10.2.1 with iptables for the Cloud NetOps lab"
