# HW10

- создаем GCE инстанс e2-medium

```bash
gcloud beta compute instances create postgres-hw10 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=100GB \
--boot-disk-type=pd-ssd \
--tags=postgres \
--restart-on-failure
```

- подключаемся к VM и устанавливаем Postgres 13 с дефолтными настройками

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql
```

- копируем датасет размером 10Гб из подготовленного заранее бакета

```bash
gsutil -m cp -R gs://bigdata12062021/taxi_trips_0000000000{10..49}.csv .

du -h ./bigdata12062021/
10G     ./bigdata12062021/
```

- подключаемся к серверу

```bash
sudo -u postgres psql
```

- создаем таблицу taxi_trips

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

- включаем тайминг

```sql
\timing
Timing is on.
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

COPY 26792963
Time: 423430.905 ms (07:03.431)
```

- проверим нашу таблицу

```sql
\d+
                             List of relations
 Schema |    Name    | Type  |  Owner   | Persistence | Size  | Description 
--------+------------+-------+----------+-------------+-------+-------------
 public | taxi_trips | table | postgres | permanent   | 11 GB | 
```

- попробуем выполнить пару запросов и оценить затраченное время

```sql
select count(*) from taxi_trips;  
  count   
----------
 26792963
(1 row)

Time: 302235.506 ms (05:02.236)


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c
FROM taxi_trips
group by payment_type
order by 3;
payment_type | tips_percent |    c
--------------+--------------+----------
 Way2ride     |            6 |        9
 Split        |           17 |      178
 Prepaid      |            0 |      943
 Pcard        |            2 |     4529
 Dispute      |            0 |     6745
 No Charge    |            4 |    82526
 Mobile       |           15 |   122689
 Unknown      |            0 |   179906
 Prcard       |            1 |   218723
 Credit Card  |           17 | 11222029
 Cash         |            0 | 14954686
(11 rows)

Time: 288209.571 ms (04:48.210)
```

> как видим, запрос выполнялся почти 5 минут

- если запустить vmstat, то можно заменить, что много процессорного времени расходуется на операции ввода-вывода (на инстансе хорошо бы увеличить количество оперативной памяти)

```bash
vmstat -SM -w 2

procs -----------------------memory---------------------- ---swap-- -----io---- -system-- --------cpu--------
 r  b         swpd         free         buff        cache   si   so    bi    bo   in   cs  us  sy  id  wa  st
 1  3            0          120           22         3419    0    0 49040   144 1012 1951   3   5  48  44   0
 0  3            0          109           22         3430    0    0 49224   128 1050 1916   4   4  47  45   0
 0  3            0          119           22         3419    0    0 49160   152 1073 1941   3   5  46  46   0
 0  4            0          111           22         3429    0    0 49164   140 1054 1925   3   4  46  47   0
 1  3            0          120           22         3419    0    0 49180   140 1035 1900   4   4  48  44   0
 0  3            0          110           22         3430    0    0 49140   156 1045 1930   4   5  47  44   0
 0  3            0          119           22         3419    0    0 49156 28826 1168 2076   4   5  47  44   0
 0  5            0          109           22         3430    0    0 49088  4990 1047 1912   3   4  48  44   0
 0  4            0          118           22         3420    0    0 49280 89462 1402 3002   5   6  48  42   0
 0  4            0          107           22         3431    0    0 49104 100540 1420 3102   3   7  48  42   0
```

- попробуем улучшить работу нашего сервера и изменим параметры в postgresql.conf

```bash
max_connections = 5
shared_buffers = 1600MB
maintenance_work_mem = 1GB
work_mem = 100MB
synchronous_commit = off
fsync = off
full_page_writes = off
effective_cache_size = 2600MB
checkpoint_timeout = 1h
max_wal_size = 2GB
```

- перезапустим сервер

```bash
sudo pg_ctlcluster 13 main restart
```

- выполним запросы повторно

```sql
select count(*) from taxi_trips; 
  count   
----------
 26792963
(1 row)

Time: 203766.510 ms (03:23.767)


SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c
FROM taxi_trips
group by payment_type
order by 3;
 payment_type | tips_percent |    c     
--------------+--------------+----------
 Way2ride     |            6 |        9
 Split        |           17 |      178
 Prepaid      |            0 |      943
 Pcard        |            2 |     4529
 Dispute      |            0 |     6745
 No Charge    |            4 |    82526
 Mobile       |           15 |   122689
 Unknown      |            0 |   179906
 Prcard       |            1 |   218723
 Credit Card  |           17 | 11222029
 Cash         |            0 | 14954686
(11 rows)

Time: 197733.315 ms (03:17.733)
```

> теперь запрос выполнился за 3 минуты (мы выиграли 1,5 минуты оптимизацией)

```остановим наш сервер
sudo pg_ctlcluster 13 main stop
```

- приступим к установке mysql

```bash
sudo apt-get update
sudo apt install mysql-server -y
systemctl status mysql
```

- создадим таблицу taxi_trips

```bash
sudo mysql
```

```sql
show tables;
+----------------+
| Tables_in_test |
+----------------+
| taxi_trips     |
+----------------+
1 row in set (0.00 sec)
```

- включим тайминг

```sql
set profiling = 1;
set global local_infile=true;
```

- для импорта csv файла используем оператор LOAD DATA LOCAL INFILE, но так как данный оператор не работает с множеством файлов, напишем скрипт для обработки каждого файла в отдельности

```bash
for f in /home/kovtalex/bigdata12062021/*.csv
do
    mysql --local-infile=1 -e "LOAD DATA LOCAL INFILE '"$f"' INTO TABLE taxi_trips FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 LINES" -u root --password=mysql test
echo "Done: '"$f"' at $(date)"
done
```

- выполним наш скрипт

- далее выполним те же самые запросы, что мы выполняли в postgres

```sql
select count(*) from taxi_trips;
+----------+
| count(*) |
+----------+
| 26792963 |
+----------+
1 row in set (3 min 22.16 sec)

SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c
    -> FROM taxi_trips
    -> group by payment_type
    -> order by 3;
+--------------+--------------+----------+
| payment_type | tips_percent | c        |
+--------------+--------------+----------+
| Way2ride     |            6 |        9 |
| Split        |           17 |      178 |
| Prepaid      |            0 |      943 |
| Pcard        |            2 |     4529 |
| Dispute      |            0 |     6745 |
| No Charge    |            4 |    82526 |
| Mobile       |           15 |   122689 |
| Unknown      |            0 |   179906 |
| Prcard       |            1 |   218723 |
| Credit Card  |           17 | 11222030 |
| Cash         |            0 | 14954686 |
+--------------+--------------+----------+
11 rows in set (3 min 22.10 sec)
```

- составим сводную таблицу по результатам

СУБД | select count(*) | select ... | Заметки
--- | --- | --- | ---
PostgreSQL | 05:02 | 04:48 | настройки по умолчанию
PostgreSQL | 03:23 | 03:17 | после оптимизации
MySQL | 03:22 | 03:22 | настройки по умолчанию

> Как видим, правильная настройка postgres позволяет увеличить скорость обработки запросов
