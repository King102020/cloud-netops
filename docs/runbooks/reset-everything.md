# Runbook: reset everything

Use this to get back to a clean clone state. It is safe: everything is
local.

```sh
./lab/clab.sh destroy                         # lab containers + clab-cnops/
lstk stop                                     # LocalStack (all AWS state is gone)
rm -rf infra/envs/local/.terraform infra/envs/local/terraform.tfstate*
docker rm -f cnops-api 2>/dev/null || true    # API container, if you ran one
```

Then follow [start-the-lab](start-the-lab.md) and the phase 3/4 run steps in
the README.
