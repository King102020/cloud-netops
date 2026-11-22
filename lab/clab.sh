#!/usr/bin/env bash
# Run containerlab for the cnops lab.
#
#   ./lab/clab.sh deploy     # build image if missing, deploy (idempotent)
#   ./lab/clab.sh destroy    # remove the lab and its clab-cnops/ folder
#   ./lab/clab.sh inspect    # list nodes and management IPs
#
# Native containerlab is used when the Docker Engine socket is local (Linux,
# or WSL with Docker Engine installed). With Docker Desktop (Windows, macOS,
# WSL integration) the daemon lives in a VM, so containerlab runs inside a
# container with --pid host, as the containerlab docs recommend.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAB_IMAGE="ghcr.io/srl-labs/clab:0.83.0"
FRR_IMAGE="cnops/frr:10.2.1"
TOPO="cnops.clab.yml"

cmd="${1:-deploy}"
shift || true
case "$cmd" in
  deploy)  args=(deploy -t "$TOPO" --reconfigure "$@") ;;
  destroy) args=(destroy -t "$TOPO" --cleanup "$@") ;;
  inspect) args=(inspect -t "$TOPO" "$@") ;;
  *)       args=("$cmd" "$@") ;;
esac

if [[ "$cmd" == deploy ]] && ! docker image inspect "$FRR_IMAGE" >/dev/null 2>&1; then
  echo "==> building $FRR_IMAGE"
  docker build -q -t "$FRR_IMAGE" "$LAB_DIR/images/frr"
fi

if command -v containerlab >/dev/null 2>&1 && [[ -S /var/run/docker.sock ]] \
  && docker info >/dev/null 2>&1; then
  cd "$LAB_DIR"
  exec containerlab "${args[@]}"
fi

# Docker Desktop: mount the lab at the path the Docker VM itself sees, so the
# bind mounts containerlab asks for resolve inside the VM.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    src="$(cygpath -m "$LAB_DIR")"          # C:/Users/...
    drive="$(printf '%s' "${src:0:1}" | tr '[:upper:]' '[:lower:]')"
    host_dir="/run/desktop/mnt/host/${drive}${src:2}"
    ;;
  Linux)
    src="$LAB_DIR"
    if [[ "$LAB_DIR" == /mnt/[a-z]/* ]]; then
      host_dir="/run/desktop/mnt/host/${LAB_DIR#/mnt/}"
    else
      host_dir="$LAB_DIR"
    fi
    ;;
  *)  # macOS: Docker Desktop shares /Users at the same path
    src="$LAB_DIR"
    host_dir="$LAB_DIR"
    ;;
esac

MSYS_NO_PATHCONV=1 docker run --rm -i --privileged --network host --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/run/netns:/var/run/netns \
  -v /var/lib/docker/containers:/var/lib/docker/containers \
  -v "$src:$host_dir" -w "$host_dir" \
  "$CLAB_IMAGE" containerlab "${args[@]}"
