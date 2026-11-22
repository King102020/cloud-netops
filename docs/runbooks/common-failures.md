# Runbook: common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| `failed to connect to the docker API` | Docker Desktop not running | Start Docker Desktop; wait for `docker info` |
| WSL: `/var/run/docker.sock: no such file` | Docker Desktop WSL integration is off for this distro | Docker Desktop → Settings → Resources → WSL integration → enable *Ubuntu-22.04*. Or run `lab/clab.sh` from Git Bash / PowerShell |
| `clab.sh deploy` says a bind path does not exist | Repo is outside the drives Docker Desktop shares | Keep the repo under `C:\Users\…` (Windows) or `/Users/…` (macOS) |
| OSPF neighbours stuck in `Init`/`ExStart` | One side's interface down, or MTU mismatch | `docker exec clab-cnops-<r> ip -br link`; redeploy with `./lab/clab.sh deploy` |
| `vtysh` prints `Can't open configuration file /etc/frr/vtysh.conf` | Old lab deployed before `vtysh.conf` was bound | `./lab/clab.sh destroy && ./lab/clab.sh deploy` |
| HTTP to `10.10.20.10` returns nothing | nginx not started on hq-srv-01 | `docker exec clab-cnops-hq-srv-01 nginx` |
| Failover test leaves HQ↔br2 down | Test interrupted mid-run | `docker exec clab-cnops-hq-core-01 ip link set eth3 up` |
| `lstk` says `Docker is not available` in WSL | Same as the WSL socket problem above | Enable WSL integration, or run `lstk` from Windows |
| `lstk start` asks for a token | LocalStack needs a (free) account token | `lstk login` once; the token is stored outside the repo |
