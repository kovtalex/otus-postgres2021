
# HW7 Блокировки

## Подготовка

- создаем GCE инстанс типа e2-medium

```bash
gcloud beta compute instances create postgres-hw7 \
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
sudo su postgres
```

## Включаем логирование о блокировках более 200мс

```sql
select current_setting('log_lock_waits');
 current_setting 
-----------------
 off
(1 row)

ALTER SYSTEM SET log_lock_waits = 'on';
SELECT name, setting, context, short_desc FROM pg_settings where name = 'log_lock_waits';


select current_setting('deadlock_timeout');
 current_setting 
-----------------
 1s
(1 row)

ALTER SYSTEM SET deadlock_timeout = '200';
SELECT name, setting, context, short_desc FROM pg_settings where name = 'deadlock_timeout';

SELECT pg_reload_conf();
```

- создадим нашу тестовую бд и таблицу

```sql
create database test;
\c test
create table test (i int);
insert into test values (1),(2),(3);
```

- создадим view для просмотра блокировок

```sql
CREATE VIEW locks AS
SELECT pid,
       locktype,
       CASE locktype
         WHEN 'relation' THEN relation::REGCLASS::text
         WHEN 'virtualxid' THEN virtualxid::text
         WHEN 'transactionid' THEN transactionid::text
         WHEN 'tuple' THEN relation::REGCLASS::text||':'||tuple::text
       END AS lockid,
       mode,
       granted
FROM pg_locks;
```

## Смоделируем ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах

- 1

```sql
begin;
SELECT txid_current(), pg_backend_pid();
 txid_current | pg_backend_pid 
--------------+----------------
          541 |           3915
(1 row)
update test set i = 5 where i = 1;
```

- 2

```sql
begin;
SELECT txid_current(), pg_backend_pid();
 txid_current | pg_backend_pid 
--------------+----------------
          542 |           3916
(1 row)
update test set i = 5 where i = 1;
```

- 3

```sql
begin;
SELECT txid_current(), pg_backend_pid();
 txid_current | pg_backend_pid 
--------------+----------------
          543 |           3917
(1 row)
update test set i = 5 where i = 1;
```

- проверим наш лог postgres на наличие информации о блокировках

```bash
cat /var/log/postgresql/postgresql-13-main.log

2021-08-27 14:30:33.297 UTC [3916] postgres@test LOG:  process 3916 still waiting for ShareLock on transaction 541 after 200.093 ms
2021-08-27 14:30:33.297 UTC [3916] postgres@test DETAIL:  Process holding the lock: 3915. Wait queue: 3916.
2021-08-27 14:30:33.297 UTC [3916] postgres@test CONTEXT:  while updating tuple (0,1) in relation "test"
2021-08-27 14:30:33.297 UTC [3916] postgres@test STATEMENT:  update test set i = 5 where i = 1;
2021-08-27 14:30:56.947 UTC [3917] postgres@test LOG:  process 3917 still waiting for ExclusiveLock on tuple (0,1) of relation 16445 of database 16444 after 200.157 ms
2021-08-27 14:30:56.947 UTC [3917] postgres@test DETAIL:  Process holding the lock: 3916. Wait queue: 3917.
2021-08-27 14:30:56.947 UTC [3917] postgres@test STATEMENT:  update test set i = 5 where i = 1;
```

- посмотрим блокировки для первой транзакции

```sql
SELECT * FROM locks WHERE pid = 3915;
 pid  |   locktype    | lockid |       mode       | granted 
------+---------------+--------+------------------+---------
 3915 | relation      | test   | RowExclusiveLock | t
 3915 | virtualxid    | 7/5    | ExclusiveLock    | t
 3915 | transactionid | 541    | ExclusiveLock    | t
(3 rows)
```

> Тип relation для test в режиме RowExclusiveLock - устанавливается на изменяемое отношение.  
> Типы virtualxid и transactionid в режиме ExclusiveLock - удерживаются каждой транзакцией для самой себя.

```sql
SELECT * FROM locks WHERE pid = 3916;
 pid  |   locktype    | lockid |       mode       | granted 
------+---------------+--------+------------------+---------
 3916 | relation      | test   | RowExclusiveLock | t
 3916 | virtualxid    | 3/1977 | ExclusiveLock    | t
 3916 | transactionid | 542    | ExclusiveLock    | t
 3916 | transactionid | 541    | ShareLock        | f
 3916 | tuple         | test:1 | ExclusiveLock    | t
(5 rows)
```

> Транзакция ожидает получение блокировки типа transactionid в режиме ShareLock для первой транзакции.  
> Удерживается блокировка типа tuple для обновляемой строки.

```sql
SELECT * FROM locks WHERE pid = 3917;
 pid  |   locktype    | lockid |       mode       | granted 
------+---------------+--------+------------------+---------
 3917 | relation      | test   | RowExclusiveLock | t
 3917 | virtualxid    | 5/3    | ExclusiveLock    | t
 3917 | transactionid | 543    | ExclusiveLock    | t
 3917 | tuple         | test:1 | ExclusiveLock    | f
(4 rows)
```

> Транзакция ожидает получение блокировки типа tuple для обновляемой строки.

- общую картину текущих ожиданий можно увидеть в представлении pg_stat_activity

```sql
SELECT pid, wait_event_type, wait_event, pg_blocking_pids(pid) FROM pg_stat_activity WHERE backend_type = 'client backend';
 pid  | wait_event_type |  wait_event   | pg_blocking_pids 
------+-----------------+---------------+------------------
 3916 | Lock            | transactionid | {3915}
 3917 | Lock            | tuple         | {3916}
 4431 |                 |               | {}
 3915 | Client          | ClientRead    | {}
(4 rows)
```

- сделаем rollback во всех сеансах

```sql
rollback;
```


## Воспроизведем взаимоблокировку трех транзакций

- 1

```sql
begin;
update test set i = 1 where i = 1;
```

- 2

```sql
begin;
update test set i = 1 where i = 2;
```

- 3

```sql
begin;
update test set i = 1 where i = 3;
```

- 1

```sql
update test set i = 1 where i = 2;
```

- 2

```sql
update test set i = 1 where i = 3;
```

- 3

```sql
update test set i = 1 where i = 1;
ERROR:  deadlock detected
DETAIL:  Process 4431 waits for ShareLock on transaction 544; blocked by process 3916.
Process 3916 waits for ShareLock on transaction 545; blocked by process 3917.
Process 3917 waits for ShareLock on transaction 546; blocked by process 4431.
HINT:  See server log for query details.
CONTEXT:  while updating tuple (0,1) in relation "test"
```

> При попытке обновления, в терминал получим информацию о deadlock

- также можно подчерпнуть информацию о deadlock в логе postgres

```bash
2021-08-27 14:47:42.177 UTC [4431] postgres@test ERROR:  deadlock detected
2021-08-27 14:47:42.177 UTC [4431] postgres@test DETAIL:  Process 4431 waits for ShareLock on transaction 550; blocked by process 4489.
        Process 4489 waits for ShareLock on transaction 551; blocked by process 3917.
        Process 3917 waits for ShareLock on transaction 552; blocked by process 4431.
        Process 4431: update test set i = 1 where i = 1;
        Process 4489: update test set i = 1 where i = 2;
        Process 3917: update test set i = 1 where i = 3;
2021-08-27 14:47:42.177 UTC [4431] postgres@test HINT:  See server log for query details.
2021-08-27 14:47:42.177 UTC [4431] postgres@test CONTEXT:  while updating tuple (0,1) in relation "test"
2021-08-27 14:47:42.177 UTC [4431] postgres@test STATEMENT:  update test set i = 1 where i = 1;
```

- сделаем rollback

```sql
rollback;
```

## Взаимоблокировка двух единственных UPDATE без WHERE в разных транзакциях

Команда UPDATE блокирует строки по мере их обновления. Это происходит не одномоментно.  
Поэтому если одна команда будет обновлять строки в одном порядке, а другая - в другом, они могут взаимозаблокироваться.  
Это может произойти, если для команд будут построены разные планы выполнения, например, одна будет читать таблицу последовательно, а другая - по индексу.
