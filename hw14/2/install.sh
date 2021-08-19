#!/bin/bash

tar zxvf cockroach-v20.1.0.linux-amd64.tgz
cp -r cockroach-v20.1.0.linux-amd64/cockroach /usr/local/bin/
mkdir /var/lib/cockroach
useradd cockroach
chown cockroach /var/lib/cockroach

cat > /etc/systemd/system/insecurecockroachdb.service <<EOF
[Unit]
Description=Cockroach Database cluster node
Requires=network.target
[Service]
Type=notify
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start --insecure --advertise-addr=$(hostname -f) --listen-addr=$(hostname -f) --cache=.25 --max-sql-memory=.25 --join=cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal,cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal,cockdb-2-eu.europe-north1-a.c.postgres2021-19850703.internal,cockdb-0-asia.asia-east1-a.c.postgres2021-19850703.internal,cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal,cockdb-2-asia.asia-east1-a.c.postgres2021-19850703.internal,cockdb-0-us.us-east1-b.c.postgres2021-19850703.internal,cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal,cockdb-2-us.us-east1-b.c.postgres2021-19850703.internal
TimeoutStopSec=60
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=cockroach
User=cockroach
[Install]
WantedBy=default.target
EOF
systemctl start insecurecockroachdb && systemctl enable insecurecockroachdb
