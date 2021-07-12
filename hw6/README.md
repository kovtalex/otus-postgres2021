
# HW6

- создаем GCE инстанс типа e2-medium

```bash
gcloud beta compute instances create postgres-hw6 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
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

- запускаем psql

```bash
sudo -u postgres psql
```

## Настройте выполнение контрольной точки

- устанавливаем время срабатывания контрольной точки каждые 30с

```sql
ALTER SYSTEM SET checkpoint_timeout = 30;
```

- включаем получение в журнале сообщений сервера информации о выполняемых контрольных точках

```sql
ALTER SYSTEM SET log_checkpoints = on;
```

- перезагружаем конфигурацию

```sql
SELECT pg_reload_conf();
```

- подготовим pgbench

```bash
sudo -u postgres pgbench -i postgres
```

- запустим pg_bench на 10 мин

```bash
sudo -u postgres pgbench -P 30 -T 600
starting vacuum...end.
progress: 30.0 s, 537.9 tps, lat 1.858 ms stddev 0.481
progress: 60.0 s, 529.8 tps, lat 1.887 ms stddev 0.493
progress: 90.0 s, 582.0 tps, lat 1.718 ms stddev 0.325
progress: 120.0 s, 501.8 tps, lat 1.992 ms stddev 0.380
progress: 150.0 s, 538.1 tps, lat 1.858 ms stddev 0.314
progress: 180.0 s, 544.9 tps, lat 1.835 ms stddev 0.306
progress: 210.0 s, 551.3 tps, lat 1.813 ms stddev 0.298
progress: 240.0 s, 539.1 tps, lat 1.854 ms stddev 0.369
progress: 270.0 s, 527.0 tps, lat 1.897 ms stddev 0.373
progress: 300.0 s, 522.9 tps, lat 1.912 ms stddev 0.351
progress: 330.0 s, 581.6 tps, lat 1.719 ms stddev 0.240
progress: 360.0 s, 588.0 tps, lat 1.700 ms stddev 0.297
progress: 390.0 s, 552.7 tps, lat 1.809 ms stddev 0.296
progress: 420.0 s, 484.8 tps, lat 2.062 ms stddev 0.408
progress: 450.0 s, 517.0 tps, lat 1.934 ms stddev 0.384
progress: 480.0 s, 533.2 tps, lat 1.875 ms stddev 0.342
progress: 510.0 s, 539.2 tps, lat 1.854 ms stddev 0.327
progress: 540.0 s, 539.7 tps, lat 1.852 ms stddev 0.339
progress: 570.0 s, 543.9 tps, lat 1.838 ms stddev 0.321
progress: 600.0 s, 557.0 tps, lat 1.795 ms stddev 0.284
```

- посмотрим log postgres

```bash
tail  /var/log/postgresql/postgresql-13-main.log 

2021-07-12 21:46:05.062 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 21:46:20.038 UTC [4003] LOG:  checkpoint complete: wrote 1932 buffers (11.8%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.950 s, sync=0.007 s, total=14.977 s; sync files=7, longest=0.004 s, average=0.001 s; distance=19639 kB, estimate=20365 kB
2021-07-12 21:46:35.050 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 21:46:50.022 UTC [4003] LOG:  checkpoint complete: wrote 1837 buffers (11.2%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.949 s, sync=0.006 s, total=14.973 s; sync files=5, longest=0.003 s, average=0.002 s; distance=19891 kB, estimate=20317 kB
2021-07-12 21:47:05.037 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 21:47:20.029 UTC [4003] LOG:  checkpoint complete: wrote 2149 buffers (13.1%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.960 s, sync=0.006 s, total=14.992 s; sync files=10, longest=0.003 s, average=0.001 s; distance=20737 kB, estimate=20737 kB
2021-07-12 21:48:05.074 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 21:48:20.054 UTC [4003] LOG:  checkpoint complete: wrote 1719 buffers (10.5%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.962 s, sync=0.004 s, total=14.980 s; sync files=10, longest=0.004 s, average=0.001 s; distance=11227 kB, estimate=19786 kB
```

> Тут видно, сколько буферов было записано, как изменился состав журнальных файлов после контрольной точки, сколько времени заняла контрольная точка и расстояние (в байтах) между соседними контрольными точками  
> В среднем на одну контрольную точку приходиться около 2000 буферов  
> Все контрольные точки выполнились по расписанию (checkpoint_completion_target = 0.5) в итоге время выполнения в логе половина от 30с

- посмотрим статистику из представления pg_stat_bgwriter

```sql
SELECT * FROM pg_stat_bgwriter \gx
-[ RECORD 1 ]---------+------------------------------
checkpoints_timed     | 22
checkpoints_req       | 0
checkpoint_write_time | 299035
checkpoint_sync_time  | 156
buffers_checkpoint    | 40314
buffers_clean         | 0
maxwritten_clean      | 0
buffers_backend       | 3830
buffers_backend_fsync | 0
buffers_alloc         | 4417
stats_reset           | 2021-07-12 21:33:22.197425+00
```

> Выполненных контрольных точек по расписанию (по достижению checkpoint_timeout) 22 (такое же количество можно было насчитать и в лог файле)

- посмотрим какие последние lsn для таблиц и каким файлам они принадлежат

```sql
postgres=# \dt
              List of relations
 Schema |       Name       | Type  |  Owner   
--------+------------------+-------+----------
 public | pgbench_accounts | table | postgres
 public | pgbench_branches | table | postgres
 public | pgbench_history  | table | postgres
 public | pgbench_tellers  | table | postgres
(4 rows)

CREATE EXTENSION pageinspect;

SELECT lsn FROM page_header(get_raw_page('pgbench_accounts',0));
    lsn     
------------
 0/1B2CE718
(1 row)

SELECT lsn FROM page_header(get_raw_page('pgbench_branches',0));
    lsn     
------------
 0/1BA14938
(1 row)


SELECT pg_walfile_name('0/1B2CE718');
     pg_walfile_name      
--------------------------
 00000001000000000000001B
(1 row)

SELECT pg_walfile_name('0/1BA14938');
     pg_walfile_name      
--------------------------
 00000001000000000000001B
(1 row)
```

> Итого имеем два wal файла

- переключимся на асинхронный режим

```sql
ALTER SYSTEM SET synchronous_commit = off;
SELECT pg_reload_conf();
```

- снова запустим pgbench

```bash
sudo -u postgres pgbench -P 30 -T 600
starting vacuum...end.
progress: 30.0 s, 1186.5 tps, lat 0.842 ms stddev 0.186
progress: 60.0 s, 1190.8 tps, lat 0.839 ms stddev 0.195
progress: 90.0 s, 1200.5 tps, lat 0.832 ms stddev 0.161
progress: 120.0 s, 1243.4 tps, lat 0.804 ms stddev 0.163
progress: 150.0 s, 651.9 tps, lat 1.534 ms stddev 9.528
progress: 180.0 s, 604.5 tps, lat 1.654 ms stddev 10.102
progress: 210.0 s, 595.3 tps, lat 1.679 ms stddev 10.181
progress: 240.0 s, 590.8 tps, lat 1.692 ms stddev 10.235
progress: 270.0 s, 570.7 tps, lat 1.752 ms stddev 10.394
progress: 300.0 s, 595.4 tps, lat 1.679 ms stddev 10.172
progress: 330.0 s, 592.7 tps, lat 1.687 ms stddev 10.196
progress: 360.0 s, 597.6 tps, lat 1.673 ms stddev 10.164
progress: 390.0 s, 595.1 tps, lat 1.680 ms stddev 10.178
progress: 420.0 s, 588.7 tps, lat 1.698 ms stddev 10.228
progress: 450.0 s, 608.8 tps, lat 1.642 ms stddev 10.089
progress: 480.0 s, 614.2 tps, lat 1.628 ms stddev 10.042
progress: 510.0 s, 599.3 tps, lat 1.668 ms stddev 10.138
progress: 540.0 s, 592.1 tps, lat 1.688 ms stddev 10.211
progress: 570.0 s, 584.1 tps, lat 1.711 ms stddev 10.258
progress: 600.0 s, 567.5 tps, lat 1.762 ms stddev 10.389
```

> Как видим tps не особо подросли, так как у нас на инстансе ssd

- посмотрим еще лог

```bash
tail  /var/log/postgresql/postgresql-13-main.log
2021-07-12 22:38:36.213 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 22:38:51.079 UTC [4003] LOG:  checkpoint complete: wrote 1828 buffers (11.2%); 0 WAL file(s) added, 0 removed, 2 recycled; write=14.843 s, sync=0.005 s, total=14.867 s; sync files=5, longest=0.003 s, average=0.001 s; distance=20534 kB, estimate=22648 kB
2021-07-12 22:39:06.213 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 22:39:21.081 UTC [4003] LOG:  checkpoint complete: wrote 2270 buffers (13.9%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.839 s, sync=0.007 s, total=14.869 s; sync files=15, longest=0.004 s, average=0.001 s; distance=20710 kB, estimate=22454 kB
2021-07-12 22:39:36.213 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 22:39:51.079 UTC [4003] LOG:  checkpoint complete: wrote 1827 buffers (11.2%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.843 s, sync=0.006 s, total=14.867 s; sync files=5, longest=0.004 s, average=0.002 s; distance=20361 kB, estimate=22245 kB
2021-07-12 22:40:06.086 UTC [4003] LOG:  checkpoint starting: time
2021-07-12 22:40:21.072 UTC [4003] LOG:  checkpoint complete: wrote 1847 buffers (11.3%); 0 WAL file(s) added, 0 removed, 1 recycled; write=14.963 s, sync=0.008 s, total=14.987 s; sync files=12, longest=0.004 s, average=0.001 s; distance=20275 kB, estimate=22048 kB
```

## Кластер с включенной контрольной суммой страниц

- создадим новый кластер и включим проверку CRC

```bash
sudo pg_dropcluster 13 main
sudo pg_createcluster 13 main

sudo -u postgres /usr/lib/postgresql/13/bin/pg_checksums --enable -D "/var/lib/postgresql/13/main"

sudo -u postgres pg_ctlcluster 13 main start
pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
13  main    5432 online postgres /var/lib/postgresql/13/main /var/log/postgresql/postgresql-13-main.log
```

- проверим включена ли проверка CRC

```sql
show data_checksums;
 data_checksums 
----------------
 on
(1 row)
```

- создадим таблицу и вставим несколько значений

```sql
create table test (i int);
insert into test values(1);
insert into test values(2);
insert into test values(3);
select i from test;

SELECT pg_relation_filepath('test');
pg_relation_filepath 
----------------------
 base/13414/16384
(1 row)
```

- выключим кластер

```bash
sudo -u postgres pg_ctlcluster 13 main stop
```

- поменяем несколько байтов в странице (сотрем из заголовка LSN последней журнальной записи)

```bash
sudo dd if=/dev/zero of=/var/lib/postgresql/13/main/base/13414/16384 oflag=dsync conv=notrunc bs=1 count=8
```

- запустим кластер

```bash
sudo -u postgres pg_ctlcluster 13 main start
```

- выполним select

```sql
select i from test;
WARNING:  page verification failed, calculated checksum 58959 but expected 41591
ERROR:  invalid page in block 0 of relation base/13414/16384
```

> у нас ошибка, что данные повреждены

- устанавливаем параметр ignore_checksum_failure, что позволяет попробовать прочитать таблицу с риском получить искаженные данные (например, если нет резервной копии)

```sql
SET ignore_checksum_failure = on;
```

- снова делаем select

```sql
select i from test;
WARNING:  page verification failed, calculated checksum 58959 but expected 41591
 i 
---
 1
 2
 3
(3 rows)
```

> видим наши данные, но с предупреждением о несовпадении контрольных сумм

- удалим наш инстанс

```bash
gcloud compute instances delete postgres-hw6
```
