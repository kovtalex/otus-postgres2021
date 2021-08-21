# HW 15

## Развернем CitusDB в GKE, зальем и шардируем 10 Гб чикагского такси

- для развертывания кластера GKE воспользуемся terraform и развернем кластер из трех нод в одном регионе

> конфигурация в папке ./terraform

```bash
terraform init
terraform validate
tflint
terraform plan
terraform apply -auto-approve
```

- по окончании развертывания посмотрим что получилось

```bash
cloud container clusters list
NAME  LOCATION       MASTER_VERSION  MASTER_IP       MACHINE_TYPE  NODE_VERSION    NUM_NODES  STATUS
k8s   europe-north1  1.20.9-gke.700  35.228.208.196  e2-medium     1.20.9-gke.700  3          RUNNING
```

- загрузим kubeconfig для работы с кластером

```bash
gcloud container clusters get-credentials k8s --region europe-north1
```

- посмотрим на наши ноды GKE

```bash
kubectl get nodes -o wide
NAME                                      STATUS   ROLES    AGE     VERSION           INTERNAL-IP   EXTERNAL-IP      OS-IMAGE                             KERNEL-VERSION   CONTAINER-RUNTIME
gke-k8s-default-node-pool-77863c3e-8xx7   Ready    <none>   2m38s   v1.20.9-gke.700   10.166.0.15   34.88.246.132    Container-Optimized OS from Google   5.4.120+         docker://20.10.3
gke-k8s-default-node-pool-7b4ed21e-zm1h   Ready    <none>   2m41s   v1.20.9-gke.700   10.166.0.13   34.88.247.157    Container-Optimized OS from Google   5.4.120+         docker://20.10.3
gke-k8s-default-node-pool-d01d8c1f-xn99   Ready    <none>   2m38s   v1.20.9-gke.700   10.166.0.14   35.228.168.251   Container-Optimized OS from Google   5.4.120+         docker://20.10.3
```

- деплоим в GKE кластер CitusDB pg12 состоящий из одного мастера и трех воркер нод (используем образ citus:10.1.1-pg12)

```bash
kubectl apply -f secrets.yaml -f entrypoint.yaml -f master.yaml -f workers.yaml
```

- посмотрим список подов (мастера и воркеры у нас стейтфулсет)

```bash
kubectl get pods
NAME             READY   STATUS    RESTARTS   AGE
citus-master-0   1/1     Running   0          99s
citus-worker-0   2/2     Running   0          97s
citus-worker-1   2/2     Running   0          69s
citus-worker-2   2/2     Running   0          40s
```

- теперь проверим, добавились ли рабочие ноды citus в мастер

```bash
kubectl exec -it citus-master-0 -- bash
```

```sql
psql -U postgres

SELECT * FROM master_get_active_worker_nodes();
          node_name           | node_port 
------------------------------+-----------
 citus-worker-2.citus-workers |      5432
 citus-worker-0.citus-workers |      5432
 citus-worker-1.citus-workers |      5432
(3 rows)
```

> Для того чтобы воркеры добавлялись к мастеру по hostname был доработан манифест пода заменой entrypoint из configMap содержащего данный entrypoint

entrypoint.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: entrypoint
data:
  entrypoint.sh: |-
    #!/bin/bash
    until psql --host=citus-master --username=postgres --command="SELECT * from master_add_node('${HOSTNAME}.citus-workers', 5432);"; do sleep 1; done &
    exec /usr/local/bin/docker-entrypoint.sh "$@"
```

workers.yaml

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: citus-workers
  labels:
    app: citus-workers
spec:
  selector:
    app: citus-workers
  clusterIP: None
  ports:
  - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: citus-worker
spec:
  selector:
    matchLabels:
      app: citus-workers
  serviceName: citus-workers
  replicas: 3
  template:
    metadata:
      labels:
        app: citus-workers
    spec:   
      containers:
      - name: citus-worker
        image: citusdata/citus:10.1.1-pg12
        command: ["/entrypoint.sh"]  # Новый entrypoint
        args: ["postgres"]           # обязательно cmd
        ports:
        - containerPort: 5432
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: citus-secrets
              key: password
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: citus-secrets
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: storage
          mountPath: /var/lib/postgresql/data
        - name: entrypoint           # Монтируем volume с entrypoint в корень контейнера
          mountPath: /entrypoint.sh
          subPath: entrypoint.sh
        livenessProbe:
          exec:
            command:
            - ./pg_healthcheck
          initialDelaySeconds: 60
      volumes:
        - name: entrypoint           # volume из configMap с entrypoint
          configMap:
            name: entrypoint
            defaultMode: 0775
  volumeClaimTemplates:
  - metadata:
      name: storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

- далее подготовим наш бакет с чикагским такси и разрешим публичный доступ ко всем csv файлам

```bash
gsutil iam ch allUsers:objectViewer gs://bigdata12062021
```

- скачаем 10Гб чикагского такси на координатор

```bash
kubectl exec -it citus-master-0 -- bash

mkdir /home/1
chmod 777 /home/1
cd /home/1
apt-get update
apt-get install wget -y
wget https://storage.googleapis.com/bigdata12062021/taxi_trips_0000000000{10..49}.csv

FINISHED --2021-08-12 15:58:33--
Total wall clock time: 1m 35s
Downloaded: 40 files, 10.0G in 1m 31s (113 MB/s)
```

> 10Гб за полторы минуты

- далее идем в postgres

```bash
psql -U postgres
```

- создадим таблицу

```sql
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

- применим партицирование по уникальному ключу

```sql
SELECT create_distributed_table('taxi_trips', 'unique_key');
```

- включим тайминг

```sql
\timing
```

- импортируем данные

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
FROM PROGRAM 'awk FNR-1 /home/1/*.csv | cat' DELIMITER ',' CSV HEADER;

COPY 27596739
Time: 696023.009 ms (11:36.023)
```

> На импорт было потрачено почти 12 минут

- зайдем на каждую из нод и посмотрим количество таблиц партицирования

```sql
1

 \dt+
                          List of relations
 Schema |       Name        | Type  |  Owner   |  Size  | Description 
--------+-------------------+-------+----------+--------+-------------
 public | taxi_trips_102008 | table | postgres | 341 MB | 
 public | taxi_trips_102011 | table | postgres | 341 MB | 
 public | taxi_trips_102014 | table | postgres | 341 MB | 
 public | taxi_trips_102017 | table | postgres | 342 MB | 
 public | taxi_trips_102020 | table | postgres | 341 MB | 
 public | taxi_trips_102023 | table | postgres | 342 MB | 
 public | taxi_trips_102026 | table | postgres | 342 MB | 
 public | taxi_trips_102029 | table | postgres | 342 MB | 
 public | taxi_trips_102032 | table | postgres | 341 MB | 
 public | taxi_trips_102035 | table | postgres | 342 MB | 
 public | taxi_trips_102038 | table | postgres | 341 MB | 
(11 rows)

2

\dt+
                          List of relations
 Schema |       Name        | Type  |  Owner   |  Size  | Description 
--------+-------------------+-------+----------+--------+-------------
 public | taxi_trips_102009 | table | postgres | 342 MB | 
 public | taxi_trips_102012 | table | postgres | 342 MB | 
 public | taxi_trips_102015 | table | postgres | 342 MB | 
 public | taxi_trips_102018 | table | postgres | 341 MB | 
 public | taxi_trips_102021 | table | postgres | 342 MB | 
 public | taxi_trips_102024 | table | postgres | 342 MB | 
 public | taxi_trips_102027 | table | postgres | 342 MB | 
 public | taxi_trips_102030 | table | postgres | 341 MB | 
 public | taxi_trips_102033 | table | postgres | 341 MB | 
 public | taxi_trips_102036 | table | postgres | 342 MB | 
 public | taxi_trips_102039 | table | postgres | 341 MB | 
(11 rows)

3

\dt+
                          List of relations
 Schema |       Name        | Type  |  Owner   |  Size  | Description 
--------+-------------------+-------+----------+--------+-------------
 public | taxi_trips_102010 | table | postgres | 342 MB | 
 public | taxi_trips_102013 | table | postgres | 342 MB | 
 public | taxi_trips_102016 | table | postgres | 342 MB | 
 public | taxi_trips_102019 | table | postgres | 341 MB | 
 public | taxi_trips_102022 | table | postgres | 342 MB | 
 public | taxi_trips_102025 | table | postgres | 342 MB | 
 public | taxi_trips_102028 | table | postgres | 342 MB | 
 public | taxi_trips_102031 | table | postgres | 342 MB | 
 public | taxi_trips_102034 | table | postgres | 341 MB | 
 public | taxi_trips_102037 | table | postgres | 341 MB | 
(10 rows)
```

> в среднем по 11 таблиц

- оценим скорость подсчета строк в нашей таблице

```sql
select count(*) from taxi_trips;
  count   
----------
 27596739
(1 row)

Time: 91116.904 ms (01:31.117)
```

- выполним запрос для оценки скорости

```sql
SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c FROM taxi_trips group by payment_type order by 3;
 payment_type | tips_percent |    c
--------------+--------------+----------
 Way2ride     |           13 |        4
 Prepaid      |            0 |       87
 Pcard        |            2 |     8064
 Dispute      |            0 |    10668
 Mobile       |           15 |    43996
 No Charge    |            5 |   115088
 Prcard       |            1 |   125790
 Unknown      |            1 |   142585
 Credit Card  |           17 | 10410852
 Cash         |            0 | 16739605
(10 rows)

Time: 126085.583 ms (02:06.086)
```

> Как видим скорость не впечатляет. Возможно требуется тюнинг PostresSQL

- ноды не особо загружены да и поды потребляют минимум во время запроса

```bash
kubectl top pods
NAME             CPU(cores)   MEMORY(bytes)
citus-master-0   11m          61Mi
citus-worker-0   85m          1009Mi
citus-worker-1   91m          783Mi
citus-worker-2   90m          802Mi

NAME                                      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
gke-k8s-default-node-pool-8a7078b0-thgg   214m         22%    1457Mi          51%       
gke-k8s-default-node-pool-b599f519-wcrp   198m         21%    1341Mi          47%       
gke-k8s-default-node-pool-c479a49f-bc8z   181m         19%    1623Mi          57%  
```

- пример с предыдущего ДЗ по cockroach с геораспределенного кластера (еще оформляю ДЗ)

```sql
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

> 14 секунд
