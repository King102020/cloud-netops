# Runbook: start the lab

1. Start Docker Desktop and wait until `docker info` works.
2. From the repo root, run `./lab/clab.sh deploy`. On Windows, use Git Bash.
3. Wait about 30 s for OSPF to converge, then check it:
   `docker exec clab-cnops-hq-core-01 vtysh -c "show ip ospf neighbor"`.
   You should see 3 neighbours in `Full`.
4. Run the tests: `lab/.venv/bin/python -m pytest lab/tests`
   (on Windows: `lab\.venv\Scripts\python -m pytest lab/tests`).
5. When finished, run `./lab/clab.sh destroy`.
