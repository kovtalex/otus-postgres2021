# HW13

- реализуем следующую схему с автоматическим переключением на рабочую ноду в кластере PostgreSQL с помощью экстеншена и сервиса pg_auto_failover

![img](./arch-multi-standby.svg)

- сбилдим pg_auto_failover c PostgreSQL 13 и запушим в docker hub

> Инструкция <https://github.com/citusdata/pg_auto_failover>

- улучшим docker-compose.yaml хелсчеками и изменим некоторые параметры

[docker-compose.yaml](./docker-compose.yaml)

- запустим наши контейнеры

```bash
docker-compose up -d
```

- проверим статус контейнеров

```bash
docker-compose ps
NAME                COMMAND                  SERVICE             STATUS              PORTS
app                 "pg_autoctl do demo …"   app                 running          
monitor             "pg_autoctl create m…"   monitor             running (healthy)   
node1               "pg_autoctl create p…"   node1               running (healthy)   
node2               "pg_autoctl create p…"   node2               running (healthy)   
node3               "pg_autoctl create p…"   node3               running (healthy) 
```

- зайдем в контейнер monitor и посмотрим версии pg_auto_failover и PostgreSQL

```bash
docker exec -it monitor bash

pg_autoctl --version

pg_autoctl version 1.6.1
pg_autoctl extension version 1.6
compiled with PostgreSQL 13.3 (Debian 13.3-1.pgdg100+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 8.3.0-6) 8.3.0, 64-bit
compatible with Postgres 10, 11, 12, 13, and 14
```

- посмотрим Postgres URI (connection string)

```bash
pg_autoctl show uri
        Type |    Name | Connection String
-------------+---------+-------------------------------
     monitor | monitor | postgres://autoctl_node@monitor:5432/pg_auto_failover?sslmode=require
   formation | default | postgres://node3:5432,node2:5432,node1:5432/analytics?target_session_attrs=read-write&sslmode=require
```

- посмотрим статус нод

```bash
pg_autoctl show state
  Name |  Node |  Host:Port |       TLI: LSN |   Connection |       Current State |      Assigned State
-------+-------+------------+----------------+--------------+---------------------+--------------------
node_1 |     1 | node3:5432 |   2: 0/415DF40 |    read-only |           secondary |           secondary
node_2 |     2 | node1:5432 |   2: 0/415DF40 |   read-write |             primary |             primary
node_3 |     3 | node2:5432 |   2: 0/415DF40 |    read-only |           secondary |           secondary
```

```bash
pg_autoctl show events
```
