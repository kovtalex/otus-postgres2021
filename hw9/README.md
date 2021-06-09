# HW 9

Подготовил инфраструктурный код Terraform развертывния инстансов и Ansible установки и первичной настройки PostgreSQL

- развертываем инфраструктуру и устанавливаем PostgreSQL

```bash
make infra-deploy INSTANCE_COUNT=4
make postgres-deploy
```

## Создадим публикацию таблицы test1, подписываемся на публикацию таблицы test2 с vm2 и публикацию таблицы test2, подписываемся на публикацию таблицы test1 с vm1

- на vm1 включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

- перезагружаем сервер

```bash
sudo pg_ctlcluster 12 main restart
```

- создаем базу, таблицу и наполняем ее

```sql
\password 
create database test;
\c test;
create table test1 (i int,str varchar(10));
insert into test1 values(1, 'строка1');
insert into test1 values(2, 'строка2');
select * from  test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- на vm2 включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

- перезагружаем сервер

```bash
sudo pg_ctlcluster 12 main restart
```

- создаем базу, таблицу и наполняем ее

```sql
\password 
create database test;
\c test;
create table test2 (i int,str varchar(10));
insert into test2 values(1, 'строка1');
insert into test2 values(2, 'строка2');
insert into test3 values(2, 'строка3');
select * from  test2;
 i |   str
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(2 rows)
```

- на vm1 создаем публикацию

```sql
CREATE PUBLICATION test1_pub FOR TABLE test1;
```

- просмотр созданной публикации

```sql
\dRp+
                      Publication test1_pub
  Owner   | All tables | Inserts | Updates | Deletes | Truncates 
----------+------------+---------+---------+---------+-----------
 postgres | f          | t       | t       | t       | t
Tables:
    "public.test1"
```

- на vm2 создаем публикацию

```sql
CREATE PUBLICATION test2_pub FOR TABLE test2;
```

- просмотр созданной публикации

```sql
\dRp+
                      Publication test2_pub
  Owner   | All tables | Inserts | Updates | Deletes | Truncates 
----------+------------+---------+---------+---------+-----------
 postgres | f          | t       | t       | t       | t
Tables:
    "public.test2"
```

- на vm1 создаем подписку

```sql
CREATE TABLE test2 (i int,str varchar(10));
CREATE SUBSCRIPTION test2_sub
 CONNECTION 'host=10.132.0.21 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test2_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
            List of subscriptions
   Name    |  Owner   | Enabled | Publication
-----------+----------+---------+-------------
 test2_sub | postgres | t       | {test1_pub}
(1 row)
```

- сделаем выборку

```sql
select * from test2;
 i |   str   
 ---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)

select * from test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- просмотр состония подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16407
subname               | test2_sub
pid                   | 14073
relid                 |
received_lsn          | 0/1691DC8
last_msg_send_time    | 2021-06-09 10:22:46.515477+00
last_msg_receipt_time | 2021-06-09 10:22:46.51602+00
latest_end_lsn        | 0/1691DC8
latest_end_time       | 2021-06-09 10:22:46.515477+00
```

> Мы успешно подписались на публикацию таблицы test2 с vm2

- на vm2 создаем подписку

```sql
CREATE TABLE test1 (i int,str varchar(10));
CREATE SUBSCRIPTION test1_sub
 CONNECTION 'host=10.132.0.20 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test1_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
            List of subscriptions
   Name    |  Owner   | Enabled | Publication 
-----------+----------+---------+-------------
 test1_sub | postgres | t       | {test1_pub}
(1 row)
```

- сделаем выборку

```sql
select * from test2;
 i |   str   
 ---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)

select * from test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- просмотр состония подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16402
subname               | test1_sub
pid                   | 13680
relid                 |
received_lsn          | 0/1692028
last_msg_send_time    | 2021-06-09 10:23:30.991077+00
last_msg_receipt_time | 2021-06-09 10:23:30.991434+00
latest_end_lsn        | 0/1692028
latest_end_time       | 2021-06-09 10:23:30.991077+00
```

> Мы успешно подписались на публикацию таблицы test1 с vm1

## vm3 используем как реплику для чтения и бэкапов (подписываемся на таблицы из vm1 и vm2)

- на vm3  включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

> На уровне logical в журнал записывается та же информация, что и на уровне hot_standby, плюс информация, необходимая для извлечения из журнала наборов логических изменений. Повышение уровня до logical приводит к значительному увеличению объёма WA.

- перезагружаем сервер

```bash
sudo pg_ctlcluster 12 main restart
```

- создаем базу и таблицу

```sql
\password 
create database test;
\c test;

CREATE TABLE test1 (i int,str varchar(10));
CREATE TABLE test2 (i int,str varchar(10));
```

- создаем подписку

```sql
CREATE SUBSCRIPTION test1_sub_vm3
 CONNECTION 'host=10.132.0.20 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test1_pub WITH (copy_data = true);
CREATE SUBSCRIPTION test2_sub_vm3
 CONNECTION 'host=10.132.0.21 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test2_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
              List of subscriptions
     Name      |  Owner   | Enabled | Publication 
---------------+----------+---------+-------------
 test1_sub_vm3 | postgres | t       | {test1_pub}
 test2_sub_vm3 | postgres | t       | {test2_pub}
(2 rows)
```

- просмотр состояния подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16398
subname               | test1_sub_vm3
pid                   | 6019
relid                 | 
received_lsn          | 0/1692108
last_msg_send_time    | 2021-06-09 10:59:38.077279+00
last_msg_receipt_time | 2021-06-09 10:59:38.077458+00
latest_end_lsn        | 0/1692108
latest_end_time       | 2021-06-09 10:59:38.077279+00
-[ RECORD 2 ]---------+------------------------------
subid                 | 16399
subname               | test2_sub_vm3
pid                   | 6022
relid                 | 
received_lsn          | 0/1691EA8
last_msg_send_time    | 2021-06-09 10:59:47.4544+00
last_msg_receipt_time | 2021-06-09 10:59:47.454506+00
latest_end_lsn        | 0/1691EA8
latest_end_time       | 2021-06-09 10:59:47.4544+00
```

- сделаем выборку

```sql

select * from test1;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
(2 rows)

select * from test2;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)
```

> Мы успешно подписались на публикации таблиц test1 с vm1 и test2 с vm2

- на vm1 проверим состояние репликации

```sql
select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 16506
usesysid         | 10
usename          | postgres
application_name | test1_sub_vm3
client_addr      | 10.132.0.22
client_hostname  | 
client_port      | 35088
backend_start    | 2021-06-09 11:52:47.079977+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1692480
write_lsn        | 0/1692480
flush_lsn        | 0/1692480
replay_lsn       | 0/1692480
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2021-06-09 17:12:10.689275+00
-[ RECORD 2 ]----+------------------------------
pid              | 14080
usesysid         | 10
usename          | postgres
application_name | test1_sub
client_addr      | 10.132.0.21
client_hostname  | 
client_port      | 47798
backend_start    | 2021-06-09 10:18:49.082061+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1692480
write_lsn        | 0/1692480
flush_lsn        | 0/1692480
replay_lsn       | 0/1692480
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2021-06-09 17:12:10.241619+00
```

- на vm1 посмотрим информацию о слотах репликации

```sql
select * from pg_replication_slots \gx
-[ RECORD 1 ]-------+--------------
slot_name           | test1_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16390
database            | test
temporary           | f
active              | t
active_pid          | 14080
xmin                | 
catalog_xmin        | 516
restart_lsn         | 0/1692448
confirmed_flush_lsn | 0/1692480
-[ RECORD 2 ]-------+--------------
slot_name           | test1_sub_vm3
plugin              | pgoutput
slot_type           | logical
datoid              | 16390
database            | test
temporary           | f
active              | t
active_pid          | 16506
xmin                | 
catalog_xmin        | 516
restart_lsn         | 0/1692448
confirmed_flush_lsn | 0/1692480
```

- на vm2 проверим состояние репликации

```sql
select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 13674
usesysid         | 10
usename          | postgres
application_name | test2_sub
client_addr      | 10.132.0.20
client_hostname  | 
client_port      | 43534
backend_start    | 2021-06-09 10:17:32.710487+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1692270
write_lsn        | 0/1692270
flush_lsn        | 0/1692270
replay_lsn       | 0/1692270
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2021-06-09 17:14:26.31076+00
-[ RECORD 2 ]----+------------------------------
pid              | 15890
usesysid         | 10
usename          | postgres
application_name | test2_sub_vm3
client_addr      | 10.132.0.22
client_hostname  | 
client_port      | 51226
backend_start    | 2021-06-09 11:52:47.088885+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1692270
write_lsn        | 0/1692270
flush_lsn        | 0/1692270
replay_lsn       | 0/1692270
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2021-06-09 17:14:26.395261+00
```

- на vm2 посмотрим информацию о слотах репликации

```sql
select * from pg_replication_slots \gx
-[ RECORD 1 ]-------+--------------
slot_name           | test2_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16391
database            | test
temporary           | f
active              | t
active_pid          | 13674
xmin                | 
catalog_xmin        | 510
restart_lsn         | 0/1692238
confirmed_flush_lsn | 0/1692270
-[ RECORD 2 ]-------+--------------
slot_name           | test2_sub_vm3
plugin              | pgoutput
slot_type           | logical
datoid              | 16391
database            | test
temporary           | f
active              | t
active_pid          | 15890
xmin                | 
catalog_xmin        | 510
restart_lsn         | 0/1692238
confirmed_flush_lsn | 0/1692270
```

## Задание со *. Реализуем горячее реплицирование для высокой доступности на vm4. Источником будет выступать vm3

- проверим необходимые настройки на vm3

```sql
select current_setting('synchronous_commit');
 current_setting 
-----------------
 on
(1 row)

select current_setting('max_wal_senders');
 current_setting 
-----------------
 10
(1 row)

select current_setting('hot_standby');
 current_setting 
-----------------
 on
(1 row)

ALTER SYSTEM SET synchronous_standby_names = '*';
ALTER SYSTEM SET wal_keep_segments = 64;

select pg_reload_conf();
```

> synchronous_commit = on - подтверждает, что произошла запись на диск в WAL файл

- перезагружаем сервер

```bash
sudo pg_ctlcluster 12 main restart
```

- настроим vm4

```bash
sudo pg_ctlcluster 12 main stop
cd /var/lib/postgresql/12/
rm -rf main
mkdir main
chmod go-rwx main
pg_basebackup -P -R -X stream -c fast -h 10.132.0.22 -U postgres -D ./main

echo "recovery_target_timeline = 'latest'" >> /etc/postgresql/12/main/recovery.conf
```

> Ключ -R создаст заготовку управляющего файла recovery.conf  
> Команда спросит пароль пользователя postgres, который мы меняли при настройке мастера. Используйте -c fast, чтобы синкнуться как можно быстрее, или -c spread, чтобы минимизировать нагрузку. Еще есть флаг -r, позволяющий ограничить скорость передачи данных  
> recovery_target_timeline = 'latest' - когда у нас упадет мастер и мы запромоутим реплику до мастера, этот параметр позволит тянуть данные с него

- стартуем сервер

```bash
sudo pg_ctlcluster 12 main start

pg_lsclusters
Ver Cluster Port Status          Owner    Data directory              Log file
12  main    5432 online,recovery postgres /var/lib/postgresql/12/main /var/log/postgresql/postgresql-12-main.log
```

- проверим необходимые настройки на vm4 (… правим аналогично vm3)

```sql
select current_setting('synchronous_commit');
 current_setting 
-----------------
 on
(1 row)

select current_setting('max_wal_senders');
 current_setting 
-----------------
 10
(1 row)

select current_setting('hot_standby');
 current_setting 
-----------------
 on
(1 row)

ALTER SYSTEM SET synchronous_standby_names = '*';
ALTER SYSTEM SET wal_keep_segments = 64;

select pg_reload_conf();
```

- рестартуем сервер

```bash
sudo pg_ctlcluster 12 main restart
```

- добавим пару строк в таблицу test2 на vm2 и сделаем выборку на vm4, чтобы убедиться, что репликация работает

```sql
select * from test1;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
(2 rows)

select * from test2;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
 4 | строка4
 5 | строка5
(5 rows)
```

- на vm3 проверим состояние репликации

```sql
select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 6596
usesysid         | 10
usename          | postgres
application_name | 12/main
client_addr      | 10.132.0.23
client_hostname  | 
client_port      | 49118
backend_start    | 2021-06-09 12:11:38.404009+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/50006C8
write_lsn        | 0/50006C8
flush_lsn        | 0/50006C8
replay_lsn       | 0/50006C8
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 1
sync_state       | sync
reply_time       | 2021-06-09 17:07:19.641009+00
```

```sql
select pg_current_wal_lsn();
 pg_current_wal_lsn 
--------------------
 0/50006C8
(1 row)
```

- на а vm4 проверим состояние репликации

```sql
select pg_last_wal_receive_lsn();
 pg_last_wal_receive_lsn 
-------------------------
 0/50006C8
(1 row)
```

```sql
select  pg_last_wal_replay_lsn();
 pg_last_wal_replay_lsn 
------------------------
 0/50006C8
(1 row)
```

```sql
select * from pg_stat_wal_receiver \gx
-[ RECORD 1 ]---------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
pid                   | 6157
status                | streaming
receive_start_lsn     | 0/5000000
receive_start_tli     | 1
received_lsn          | 0/50006C8
received_tli          | 1
last_msg_send_time    | 2021-06-09 17:51:56.830585+00
last_msg_receipt_time | 2021-06-09 17:51:56.831384+00
latest_end_lsn        | 0/50006C8
latest_end_time       | 2021-06-09 12:46:36.680954+00
slot_name             | 
sender_host           | 10.132.0.22
sender_port           | 5432
conninfo              | user=postgres password=******** dbname=replication host=10.132.0.22 port=5432 fallback_application_name=12/main sslmode=prefer sslcompression=0 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
```

- также на vm4 можно смотреть, как давно было последнее обновление данных с vm3

```sql
select now()-pg_last_xact_replay_timestamp();
    ?column?     
-----------------
 00:00:46.636766
(1 row)
```

- удалим нашу инфраструктуру

```bash
make infra-destroy
```
