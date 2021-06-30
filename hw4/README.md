# HW4

- создаем виртуальную машину

```bash
gcloud beta compute instances create postgres-hw4 \
--machine-type=n1-standard-1 \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
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

- заходим в postgres

```bash
sudo -u postgres psql
```

- создаем новую баз данных testdb

```sql
CREATE DATABASE testdb;
```

- заходим в созданную базу данных под пользователем postgres

```bash
\c testdb
You are now connected to database "testdb" as user "postgres".
```

- создаем новую схему testnm

```sql
CREATE SCHEMA testnm;
```

- создаем новую таблицу t1 с одной колонкой c1 типа integer

```sql
CREATE TABLE t1(c1 int);
```

- вставляем строку со значением c1=1

```sql
INSERT INTO t1 values(1);
```

- создаем новую роль readonly

```sql
CREATE ROLE readonly;
```

- даем новой роли право на подключение к базе данных testdb

```sql
GRANT CONNECT ON DATABASE testdb TO readonly;
```

- даем новой роли право на использование схемы testnm

```sql
GRANT USAGE ON SCHEMA testnm TO readonly;
```

- даем новой роли право на select для всех таблиц схемы testnm

```sql
GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;
```

- создаем пользователя testread с паролем test123

```sql
CREATE USER testread WITH PASSWORD 'test123';
```

- даем роль readonly пользователю testread

```sql
GRANT readonly TO testread;
```

- зайдем под пользователем testread в базу данных testdb

```bash
/etc/postgresql/13/main/pg_hba.conf
host    testdb          testread        127.0.0.1/32            md5
```

```bash
sudo pg_ctlcluster 13 main restart
```

```bash
psql -U testread -h 127.0.0.1 -W -d testdb
```

- сделаем select * from t1;

```sql
SELECT * FROM t1;
ERROR:  permission denied for table t1
```

> Не смогли выполнить запрос, так как у нас право на выполнение **select** только для схемы **testnm**  
> В search_path указано "$user", public при том что схемы $user нет, то таблица по умолчанию создалась в **public**

```sql
 \dt
        List of relations
 Schema | Name | Type  |  Owner
--------+------+-------+----------
 public | t1   | table | postgres
(1 row)
```

- вернемся в базу данных testdb под пользователем postgres

```bash
sudo -u postgres psql
```

```sql
\c testdb
```

- удалим таблицу t1

```sql
DROP TABLE t1;
```

- создадим ее заново, но уже с явным указанием имени схемы testnm

```sql
CREATE TABLE testnm.t1(c1 int);

\dt testnm.*
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 testnm | t1   | table | postgres
(1 row)
```

- вставим строку со значением c1=1

```sql
INSERT INTO testnm.t1 values(1);
```

- зайдем под пользователем testread в базу данных testdb

```bash
psql -U testread -h 127.0.0.1 -W -d testdb
```

- сделаем select * from testnm.t1;

```sql
SELECT * FROM testnm.t1;
ERROR:  permission denied for table t1
```

> Не смогли выполнить запрос, так как **GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;** дал доступ **только** для существующих на тот момент таблиц, а t1 пересоздавалась

- вернемся в базу данных testdb под пользователем postgres

```bash
sudo -u postgres psql
```

```sql
\c testdb
```

- даем роли readonly право на select для всех таблиц схемы testnm

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA testnm GRANT SELECT ON TABLES to readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;
```

- зайдем под пользователем testread в базу данных testdb

```bash
psql -U testread -h 127.0.0.1 -W -d testdb
```

> Для peer аутентификация **\c testdb testread;**

- сделаем select * from testnm.t1;

```sql
select * from testnm.t1;
 c1 
----
  1
(1 row)
```

> **ALTER DEFAULT** будет действовать для новых таблиц, а **GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;** отработал только для существующих на тот момент времени  
> Надо было сделать снова **GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;** или пересоздать таблицу

- выполним create table и insert

```sql
create table t2(c1 integer); 
CREATE TABLE

insert into t2 values (2);
INSERT 0 1
```

> t2 была создана в схеме public, которая указана в search_path

```sql
select * from pg_namespace;
  oid  |      nspname       | nspowner |                   nspacl                   
-------+--------------------+----------+--------------------------------------------
    99 | pg_toast           |       10 | 
    11 | pg_catalog         |       10 | {postgres=UC/postgres,=U/postgres}
  2200 | public             |       10 | {postgres=UC/postgres,=UC/postgres}
 13130 | information_schema |       10 | {postgres=UC/postgres,=U/postgres}
 16385 | testnm             |       10 | {postgres=UC/postgres,readonly=U/postgres}
(5 rows)

show search_path;
   search_path   
-----------------
 "$user", public
(1 row)
```

> Каждый пользователь может по умолчанию создавать объекты в схеме **public** любой базы данных, если у него есть право на подключение к этой базе данных  
> Хорошая практика - это убирать права у public

- отзовем права у роли public для схемs public и длЖйя бд testdb

```bash
sudo -u postgres psql
```

```sql
\c testdb
\dn
  List of schemas
  Name  |  Owner   
--------+----------
 public | postgres
 testnm | postgres
(2 rows)

revoke create on schema public from public; 
revoke all on database testdb from public; 
```

- теперь выполним от пользователя testread

```bash
psql -U testread -h 127.0.0.1 -W -d testdb
```

```sql
\c testdb

create table t3 (c1 integer);
ERROR:  permission denied for schema public

insert into t2 values (2); 
ERROR:  permission denied for table t2
```

> Теперь от пользователя testread мы не можем создавать объекты в схеме public

```sql
\dp testnm.*
                                Access privileges
 Schema | Name | Type  |     Access privileges     | Column privileges | Policies 
--------+------+-------+---------------------------+-------------------+----------
 testnm | t1   | table | postgres=arwdDxt/postgres+|                   | 
        |      |       | readonly=r/postgres       |                   | 

\dp public.*
                            Access privileges
 Schema | Name | Type  | Access privileges | Column privileges | Policies 
--------+------+-------+-------------------+-------------------+----------
 public | t2   | table |                   |                   | 
(1 row)
```
