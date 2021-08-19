# HW14

## Вариант 1: Развернем CockroachDB в GKE, зальем 10 Гб данных и протестируем скорость запросов в сравнении с 1 инстансом PostgreSQL

- воспользуемя terraform для развертывания кластера в GKE состоящего из трех нод

```bash
cd ./1/terraform
terraform init
terraform plan
terraform apply
```

- по окончании развертывания посмотрим что получилось

```bash
cloud container clusters list
NAME  LOCATION       MASTER_VERSION  MASTER_IP       MACHINE_TYPE  NODE_VERSION    NUM_NODES  STATUS
k8s   europe-north1  1.20.9-gke.1000  35.228.136.110  e2-medium     1.20.9-gke.1000  3          RUNNING
```

- загрузим kubeconfig для работы с кластером

```bash
gcloud container clusters get-credentials k8s --region europe-north1
```

- посмотрим на наши ноды GKE

```bash
kubectl get nodes -o wide
NAME                                      STATUS   ROLES    AGE    VERSION            INTERNAL-IP   EXTERNAL-IP      OS-IMAGE                             KERNEL-VERSION   CONTAINER-RUNTIME
gke-k8s-default-node-pool-22db254d-f8l2   Ready    <none>   94s    v1.20.9-gke.1000   10.166.0.21   35.228.168.251   Container-Optimized OS from Google   5.4.120+         docker://20.10.3
gke-k8s-default-node-pool-58a8cd95-5l8s   Ready    <none>   108s   v1.20.9-gke.1000   10.166.0.19   34.88.246.132    Container-Optimized OS from Google   5.4.120+         docker://20.10.3
gke-k8s-default-node-pool-8b4f407a-3175   Ready    <none>   104s   v1.20.9-gke.1000   10.166.0.20   35.228.180.34    Container-Optimized OS from Google   5.4.120+         docker://20.10.3
```

- добавим репозиторий чартов cockroachdb и обновим список

```bash
helm repo add cockroachdb https://charts.cockroachdb.com/
helm repo update
```

- модифицируем наш values.yaml

```yml
statefulset:
  resources:
    limits:
      memory: 2Gi
    requests:
      memory: 2Gi
conf:
  cache: 1Gi
  max-sql-memory: 1Gi
storage:
  persistentVolume:
    size: 10Gi
service:
  public:
    type: LoadBalancer
```

- и установим cockroarch из helm чарта

```bash
helm upgrade --install cockroach cockroachdb/cockroachdb -f ./values.yaml

Release "cockroach" has been upgraded. Happy Helming!
NAME: cockroach
LAST DEPLOYED: Fri Aug 13 14:15:30 2021
NAMESPACE: default
STATUS: deployed
REVISION: 2
NOTES:
CockroachDB can be accessed via port 26257 at the
following DNS name from within your cluster:

cockroach-cockroachdb-public.default.svc.cluster.local

Because CockroachDB supports the PostgreSQL wire protocol, you can connect to
the cluster using any available PostgreSQL client.

For example, you can open up a SQL shell to the cluster by running:

    kubectl run -it --rm cockroach-client \
        --image=cockroachdb/cockroach \
        --restart=Never \
        --command -- \
        ./cockroach sql --insecure --host=cockroach-cockroachdb-public.default

From there, you can interact with the SQL shell as you would any other SQL
shell, confident that any data you write will be safe and available even if
parts of your cluster fail.

Finally, to open up the CockroachDB admin UI, you can port-forward from your
local machine into one of the instances in the cluster:

    kubectl port-forward cockroach-cockroachdb-0 8080

Then you can access the admin UI at http://localhost:8080/ in your web browser.

For more information on using CockroachDB, please see the project's docs at:
https://www.cockroachlabs.com/docs/
```

- посмотрим созданные поды

```bash
kubectl get pods -o wide 
NAME                      READY   STATUS    RESTARTS   AGE   IP           NODE                                      NOMINATED NODE   READINESS GATES
cockroach-cockroachdb-0   1/1     Running   0          14m   10.116.1.4   gke-k8s-default-node-pool-8b4f407a-3175   <none>           <none>
cockroach-cockroachdb-1   1/1     Running   0          14m   10.116.2.5   gke-k8s-default-node-pool-22db254d-f8l2   <none>           <none>
cockroach-cockroachdb-2   1/1     Running   0          14m   10.116.0.6   gke-k8s-default-node-pool-58a8cd95-5l8s   <none>           <none>
```

- далее идем в кластер cockroach

```bash
psql -h 34.88.247.157  -p 26257 -U root
```

- создаем бд и таблицу

```sql
create database taxi;
 \c taxi

create table taxi_trips (
unique_key text, 
taxi_id text, 
trip_start_timestamp TIMESTAMP, 
trip_end_timestamp TIMESTAMP, 
trip_seconds bigint, 
trip_miles numeric, 
pickup_census_tract bigint, 
dropoff_census_tract bigint, 
pickup_community_area bigint, 
dropoff_community_area bigint, 
fare numeric, 
tips numeric, 
tolls numeric, 
extras numeric, 
trip_total numeric, 
payment_type text, 
company text, 
pickup_latitude numeric, 
pickup_longitude numeric, 
pickup_location text, 
dropoff_latitude numeric, 
dropoff_longitude numeric, 
dropoff_location text
);
```

- посмотрим на ноды кластера cockroach

```bash
kubectl run -it --rm cockroach-client \
        --image=cockroachdb/cockroach \
        --restart=Never \
        --command -- \
        ./cockroach node status --insecure --host=cockroach-cockroachdb-public.default
  id |                                    address                                    |                                  sql_address                                  |  build  |         started_at         |         updated_at         | locality | is_available | is_live
-----+-------------------------------------------------------------------------------+-------------------------------------------------------------------------------+---------+----------------------------+----------------------------+----------+--------------+----------
   1 | cockroach-cockroachdb-0.cockroach-cockroachdb.default.svc.cluster.local:26257 | cockroach-cockroachdb-0.cockroach-cockroachdb.default.svc.cluster.local:26257 | v21.1.7 | 2021-08-18 20:25:42.116394 | 2021-08-18 20:47:36.338213 |          | true         | true
   2 | cockroach-cockroachdb-1.cockroach-cockroachdb.default.svc.cluster.local:26257 | cockroach-cockroachdb-1.cockroach-cockroachdb.default.svc.cluster.local:26257 | v21.1.7 | 2021-08-18 20:27:15.613649 | 2021-08-18 20:47:35.393608 |          | true         | true
   3 | cockroach-cockroachdb-2.cockroach-cockroachdb.default.svc.cluster.local:26257 | cockroach-cockroachdb-2.cockroach-cockroachdb.default.svc.cluster.local:26257 | v21.1.7 | 2021-08-18 20:20:11.989278 | 2021-08-18 20:47:39.178888 |          | true         | true
(3 rows)
```

- в GCP создаем service account и экспортируем ключ в json

```bash
export KEY=$(cat ~/key.json | base64)
```

- импортируем 10Гб chicago taxi

```bash
for i in {10..49}
do
  echo "$i"; psql -h 34.88.247.157 -p 26257 -U root -d taxi -c "IMPORT INTO taxi_trips CSV DATA ('gs://bigdata12062021/taxi_trips_0000000000$i.csv?AUTH=specified&CREDENTIALS=${KEY}') WITH delimiter = ',', nullif = '', skip = '1'"
done
```

- далее логинимся в наш кластер

```bash
psql -h 34.88.247.157  -p 26257 -U root
```

- выполним пару запросов

```sql
\c taxi
\timing

select count(*) from taxi_trips;
  count   
----------
 27327467
(1 row)

Time: 34150,648 ms (00:34,151)


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c FROM taxi_trips group by payment_type order by 3;
 payment_type | tips_percent |    c     
--------------+--------------+----------
 Way2ride     |           13 |        4
 Prepaid      |            0 |       89
 Pcard        |            2 |     7668
 Dispute      |            0 |    11057
 Prcard       |            1 |    33010
 Mobile       |           15 |    36323
 Unknown      |            2 |    72707
 No Charge    |            4 |   119336
 Credit Card  |           17 | 10052957
 Cash         |            0 | 16994316
(10 rows)

Time: 55889,087 ms (00:55,889)
```

- теперь развернем одиночный инстанс аналогичный по ресурсам

```bash
gcloud beta compute instances create postgres-hw14 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=100GB \
--boot-disk-type=pd-ssd \
--tags=postgres \
--restart-on-failure
```

- подключаемся к VM и устанавливаем Postgres

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql
```

- копируем датасет размером 10Гб из подготовленного заранее бакета

```bash
mkdir bigdata12062021
cd bigdata12062021
gsutil -m cp -R gs://bigdata12062021/taxi_trips_0000000000{10..49}.csv .
cd ..

du -h ./bigdata12062021/
10G     ./bigdata12062021/
```

- подтюним наш postgres

```bash
max_connections = 20
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 26214kB
min_wal_size = 1GB
max_wal_size = 4GB

sudo pg_ctlcluster 13 main restart
```

- подключаемся

```bash
sudo -u postgres psql
```

- создаем базу данных и таблицу taxi_trips

```sql
create database taxi;
\c taxi

create table taxi_trips (
unique_key text, 
taxi_id text, 
trip_start_timestamp TIMESTAMP, 
trip_end_timestamp TIMESTAMP, 
trip_seconds bigint, 
trip_miles numeric, 
pickup_census_tract bigint, 
dropoff_census_tract bigint, 
pickup_community_area bigint, 
dropoff_community_area bigint, 
fare numeric, 
tips numeric, 
tolls numeric, 
extras numeric, 
trip_total numeric, 
payment_type text, 
company text, 
pickup_latitude numeric, 
pickup_longitude numeric, 
pickup_location text, 
dropoff_latitude numeric, 
dropoff_longitude numeric, 
dropoff_location text
);
```

- загружаем данные из csv файлов

```sql
COPY taxi_trips(unique_key, 
taxi_id, 
trip_start_timestamp, 
trip_end_timestamp, 
trip_seconds, 
trip_miles, 
pickup_census_tract, 
dropoff_census_tract, 
pickup_community_area, 
dropoff_community_area, 
fare, 
tips, 
tolls, 
extras, 
trip_total, 
payment_type, 
company, 
pickup_latitude, 
pickup_longitude, 
pickup_location, 
dropoff_latitude, 
dropoff_longitude, 
dropoff_location)
FROM PROGRAM 'awk FNR-1 /home/kovtalex/bigdata12062021/*.csv | cat' DELIMITER ',' CSV HEADER;

COPY 27327466
```

- проверим нашу таблицу

```sql
\d+
                             List of relations
 Schema |    Name    | Type  |  Owner   | Persistence | Size  | Description 
--------+------------+-------+----------+-------------+-------+-------------
 public | taxi_trips | table | postgres | permanent   | 11 GB | 
```

- включаем тайминг

```sql
\timing
Timing is on.
```

- попробуем выполнить пару запросов и оценить затраченное время

```sql
select count(*) from taxi_trips;  
  count   
----------
 27327466
(1 row)

Time: 201934.981 ms (03:21.935)


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c
FROM taxi_trips
group by payment_type
order by 3;
 payment_type | tips_percent |    c     
--------------+--------------+----------
 Way2ride     |           13 |        4
 Prepaid      |            0 |       89
 Pcard        |            2 |     7668
 Dispute      |            0 |    11057
 Prcard       |            1 |    33010
 Mobile       |           15 |    36323
 Unknown      |            2 |    72707
 No Charge    |            4 |   119336
 Credit Card  |           17 | 10052956
 Cash         |            0 | 16994316
(10 rows)

Time: 218547.464 ms (03:38.547)
```

> В конце ДЗ сводная табличка

## Вариант 2: перенесем тестовую БД 10 Гб в географически распределенный PostgeSQL like сервис CockroachDB

С помощью terraform развернем:

- vpc для трех регионов
- три инстанса в каждом регионе
- bastion vm для удобства работы

```bash
cd ./2/terraform
terraform init
terraform plan
terraform apply
```

- посмотрим список vpc

```bash
gcloud compute networks list
NAME      SUBNET_MODE  BGP_ROUTING_MODE  IPV4_RANGE  GATEWAY_IPV4
default   AUTO         REGIONAL
otus-vpc  CUSTOM       GLOBAL

gcloud compute networks subnets list | grep otus-vpc
otus-subn-asia-e1  asia-east1               otus-vpc  10.0.30.0/24   IPV4_ONLY
otus-subn-us-e1    us-east1                 otus-vpc  10.0.20.0/24   IPV4_ONLY
otus-subn-eu-n1    europe-north1            otus-vpc  10.0.10.0/24   IPV4_ONLY
```

- посмотрим список инстансов

```bash
gcloud compute  instances list
NAME           ZONE             MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
cockdb-0-asia  asia-east1-a     e2-medium                  10.0.30.2                   RUNNING
cockdb-1-asia  asia-east1-a     e2-medium                  10.0.30.3                   RUNNING
cockdb-2-asia  asia-east1-a     e2-medium                  10.0.30.4                   RUNNING
cockdb-0-us    us-east1-b       e2-medium                  10.0.20.4                   RUNNING
cockdb-1-us    us-east1-b       e2-medium                  10.0.20.3                   RUNNING
cockdb-2-us    us-east1-b       e2-medium                  10.0.20.2                   RUNNING
cockdb-0-eu    europe-north1-a  e2-medium                  10.0.10.4                   RUNNING
cockdb-1-eu    europe-north1-a  e2-medium                  10.0.10.2                   RUNNING
cockdb-2-eu    europe-north1-a  e2-medium                  10.0.10.3                   RUNNING
vm-bastion     europe-north1-a  e2-medium                  10.0.10.5    34.88.247.157  RUNNING
```

- скопируем подготовленные скрипты развертывания cockroach на vm-bastion

```bash
gcloud compute scp ../*.sh vm-bastion:.
```

- зайдем на vm-bastion и скачает архив с бинарником cockroach

```bash
gcloud compute ssh vm-bastion
mkdir ~/.ssh
vi ~/.ssh/id_rsa
chmod go-rw ~/.ssh/id_rsa
echo "Host *" > ~/.ssh/config
echo " StrictHostKeyChecking no" >> ~/.ssh/config

wget https://binaries.cockroachdb.com/cockroach-v20.1.0.linux-amd64.tgz
```

- запустим деплой и настройки нашего кластера. по окончании будет выведен список node кластера

```bash
./deploy.sh

  id |                              address                               |                            sql_address                             |  build  |            started_at            |            updated_at            | locality | is_available | is_live
-----+--------------------------------------------------------------------+--------------------------------------------------------------------+---------+----------------------------------+----------------------------------+----------+--------------+----------
   1 | cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | v20.1.0 | 2021-08-10 13:28:08.788159+00:00 | 2021-08-10 13:28:44.809505+00:00 |          | true         | true
   2 | cockdb-2-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | cockdb-2-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | v20.1.0 | 2021-08-10 13:28:10.806417+00:00 | 2021-08-10 13:28:42.331843+00:00 |          | true         | true
   3 | cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal:26257 | v20.1.0 | 2021-08-10 13:28:11.51142+00:00  | 2021-08-10 13:28:43.033796+00:00 |          | true         | true
   4 | cockdb-0-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | cockdb-0-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | v20.1.0 | 2021-08-10 13:28:11.984474+00:00 | 2021-08-10 13:28:43.958587+00:00 |          | true         | true
   5 | cockdb-0-us.us-east1-b.c.postgres2021-19850703.internal:26257      | cockdb-0-us.us-east1-b.c.postgres2021-19850703.internal:26257      | v20.1.0 | 2021-08-10 13:28:11.973319+00:00 | 2021-08-10 13:28:43.67597+00:00  |          | true         | true
   6 | cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal:26257      | cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal:26257      | v20.1.0 | 2021-08-10 13:28:12.027279+00:00 | 2021-08-10 13:28:43.751976+00:00 |          | true         | true
   7 | cockdb-2-us.us-east1-b.c.postgres2021-19850703.internal:26257      | cockdb-2-us.us-east1-b.c.postgres2021-19850703.internal:26257      | v20.1.0 | 2021-08-10 13:28:12.485542+00:00 | 2021-08-10 13:28:44.182133+00:00 |          | true         | true
   8 | cockdb-2-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | cockdb-2-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | v20.1.0 | 2021-08-10 13:28:13.052931+00:00 | 2021-08-10 13:28:45.017018+00:00 |          | true         | true
   9 | cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal:26257  | v20.1.0 | 2021-08-10 13:28:14.398087+00:00 | 2021-08-10 13:28:41.865719+00:00 |          | true         | true
(9 rows)
```

- скопируем датасет размером 10Гб из подготовленного заранее бакета на один из инстансов

```bash
ssh kovtalex@cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal

mkdir taxi_trips
gcloud auth login
gsutil -m cp -R gs://bigdata12062021/0000000000{10..49}.csv ./taxi_trips
sudo mkdir -p /var/lib/cockroach/cockroach-data/extern
sudo mv taxi_trips /var/lib/cockroach/cockroach-data/extern
```

- зайдем в cockroach на одном из инстансов

```bash
cockroach sql --insecure --host cockdb-0-eu.europe-north1-a.c.postgres2021-19850703.internal
```

- и создадим базу и таблицу для дальнейшего импорта чикагского такси

```sql
create database taxi;

use taxi;

create table taxi_trips (
unique_key text, 
taxi_id text, 
trip_start_timestamp TIMESTAMP, 
trip_end_timestamp TIMESTAMP, 
trip_seconds bigint, 
trip_miles numeric, 
pickup_census_tract bigint, 
dropoff_census_tract bigint, 
pickup_community_area bigint, 
dropoff_community_area bigint, 
fare numeric, 
tips numeric, 
tolls numeric, 
extras numeric, 
trip_total numeric, 
payment_type text, 
company text, 
pickup_latitude numeric, 
pickup_longitude numeric, 
pickup_location text, 
dropoff_latitude numeric, 
dropoff_longitude numeric, 
dropoff_location text
);
```

- подготовим небольшой скрипт импорта в базу и запустим его

```bash
#!/bin/bash

date
for i in {10..49}
do
  echo "$i"; cockroach sql --insecure --host=cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal --database="taxi" --execute="IMPORT INTO taxi_trips CSV DATA ('nodelocal://1/taxi_trips/0000000000$i.csv') WITH delimiter = ',', nullif = '', skip = '1'"
done
date
```

> Импорт занял полтора часа

- теперь выполним запросы к нашей таблице в каждом из регионов и посмотрим на скорость выполнения

### europe-north1

```bash
ssh kovtalex@cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal
cockroach sql --insecure --host cockdb-1-eu.europe-north1-a.c.postgres2021-19850703.internal
```

```sql
use taxi;
select count(*) from taxi_trips;
   count
------------
  27665670
(1 row)

Time: 24.96319894s


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c FROM taxi_trips group by payment_type order by 3;
  payment_type | tips_percent |    c
---------------+--------------+-----------
  Prepaid      |            0 |       89
  Pcard        |            2 |     7336
  Dispute      |            0 |    11415
  Mobile       |           15 |    46528
  No Charge    |            5 |   123626
  Prcard       |            1 |   127544
  Unknown      |            1 |   142009
  Credit Card  |           17 | 10325567
  Cash         |            0 | 16881556
(9 rows)

Time: 15.858092922s
```

### asia-east1

```bash
ssh kovtalex@cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal

cockroach sql --insecure --host cockdb-1-asia.asia-east1-a.c.postgres2021-19850703.internal
```

```sql
use taxi;
select count(*) from taxi_trips;
   count
------------
  27665670
(1 row)

Time: 5.386874814s


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c FROM taxi_trips group by payment_type order by 3;
  payment_type | tips_percent |    c
---------------+--------------+-----------
  Prepaid      |            0 |       89
  Pcard        |            2 |     7336
  Dispute      |            0 |    11415
  Mobile       |           15 |    46528
  No Charge    |            5 |   123626
  Prcard       |            1 |   127544
  Unknown      |            1 |   142009
  Credit Card  |           17 | 10325567
  Cash         |            0 | 16881556
(9 rows)

Time: 14.899039089s
```

### us-east1-b

```bash
ssh kovtalex@cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal
cockroach sql --insecure --host cockdb-1-us.us-east1-b.c.postgres2021-19850703.internal
```

```sql
use taxi;
select count(*) from taxi_trips;
   count
------------
  27665670
(1 row)

Time: 5.204747878s


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c FROM taxi_trips group by payment_type order by 3;
  payment_type | tips_percent |    c
---------------+--------------+-----------
  Prepaid      |            0 |       89
  Pcard        |            2 |     7336
  Dispute      |            0 |    11415
  Mobile       |           15 |    46528
  No Charge    |            5 |   123626
  Prcard       |            1 |   127544
  Unknown      |            1 |   142009
  Credit Card  |           17 | 10325567
  Cash         |            0 | 16881556
(9 rows)

Time: 13.666771626s
```

> Достаточно быстро!

## Результаты

Кластер | select count(*) | select tips
--- | --- | ---
CockroachDB в GKE (3 ноды) | 34с | 56с
Одиночный инстанс Postgresq | 3м | 3м38с
Геокластер CockroachDB (9 нод) | 5с | 13с

> Чем больше нод - тем быстрее)
