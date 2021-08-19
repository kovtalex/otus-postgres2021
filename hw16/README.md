# HW16

## Развернем CloudSQL и протестируем на 10Гб чикагского такси

- создадим PostgreSQL instance

key | value
--- | ---
Region | europe-north1 (Finland)
DB Version | PostgreSQL 13
vCPUs | 2 vCPU
Memory | 4 GB
Storage | 100 GB
Network throughput (MB/s) | 500 of 2,000
Disk throughput (MB/s) | Read: 48.0 of 240.0
Disk throughput (MB/s) | Write: 48.0 of 144.0
IOPS | Read: 3,000 of 15,000
IOPS | Write: 3,000 of 9,000
Connections | Public IP
Backup | Manual
Availability | Single zone
Point-in-time recovery | Disabled

- копируем датасет размером 10Гб из подготовленного заранее бакета

```bash
mkdir bigdata12062021
cd bigdata12062021
gsutil -m cp -R gs://bigdata12062021/taxi_trips_0000000000{10..49}.csv .

cd ..
du -h ./bigdata12062021/
10G     ./bigdata12062021/
```

- сохраним пароль подключения к postgres в переменной окружения

```bash
export PGPASSWORD=somepass
```

- подключаемся к серверу

```bash
psql -h 34.88.43.52 -U postgres
```

- создаем базу данных taxi и таблицу taxi_trips

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

```bash
for i in {12..49}
do
  echo "$i"; psql -h 34.88.43.52 -U postgres -d taxi -c "\COPY taxi_trips FROM  './bigdata12062021/taxi_trips_0000000000$i.csv' DELIMITER ',' CSV HEADER;"
done
```

```bash
psql -h 34.88.43.52 -U postgres
```

- проверим нашу таблицу

```sql
\c taxi
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
 27327467
(1 row)

Time: 145387,299 ms (02:25,387)


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
 Credit Card  |           17 | 10052957
 Cash         |            0 | 16994316
(10 rows)

Time: 146361,958 ms (02:26,362)
```

- сравним с результатами из ДЗ №14 (все инстансы совпадают по характеристикам)

Кластер | select count(*) | select tips
--- | --- | ---
CockroachDB в GKE (3 ноды) | 34с | 56с
Геокластер CockroachDB (9 нод) | 5с | 13с
Одиночный инстанс Postgres | 3м | 3м38с
CloudSQL | 2м25с | 2м26с

> Как видим наш CloudSQL оказался немного быстрее одиночного GCE инстанса с PostgreSQL
