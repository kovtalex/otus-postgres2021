#!/bin/bash

scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-2-eu.europe-north1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-0-asia.asia-east1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-2-asia.asia-east1-a.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-0-us.us-east1-b.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal:.
scp install.sh cockroach-v20.1.0.linux-amd64.tgz kovtalex@cockdb-2-us.us-east1-b.c.postgres2021-19850703.internal:.

ssh -t kovtalex@cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-2-eu.europe-north1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-0-asia.asia-east1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-2-asia.asia-east1-a.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-0-us.us-east1-b.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal "sudo ./install.sh"
ssh -t kovtalex@cockdb-2-us.us-east1-b.c.postgres2021-19850703.internal "sudo ./install.sh"

ssh -t kovtalex@cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal "cockroach init --insecure --host cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal"

ssh -t kovtalex@cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal "/usr/local/bin/cockroach node status --host cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal --insecure"
