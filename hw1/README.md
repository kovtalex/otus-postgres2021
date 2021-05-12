# HW1

- создаем новый проект в Google Cloud Platform
- далее создаем инстанс виртуальной машины Compute Engine с дефолтными параметрами

```bash
gcloud config set project postgresXXXX-XXXXXXXX

gcloud beta compute instances create postgres-hw1 \
--machine-type=n1-standard-1 \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--restart-on-failure
```

- добавляем свой ssh ключ в GCE metadata
- заходим удаленным ssh (первая сессия), не забывайте про ssh-add

```bash
ssh 34.76.199.123
```

- устанавливаем PostgreSQL

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql
```

- заходим вторым ssh (вторая сессия)

```bash
ssh 34.76.199.123
```

- запускаем везде psql из под пользователя postgres

```bash
sudo -u postgres psql
```

- выключаем auto commit в обеих сессиях

```bash
\echo :AUTOCOMMIT
on
\set AUTOCOMMIT OFF
\echo :AUTOCOMMIT
OFF
```

- делаем в первой сессии новую таблицу и наполняем ее данными

```bash
create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov');
insert into persons(first_name, second_name) values('petr', 'petrov');
commit;

select * from persons;

 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
(2 rows)
```

### TRANSACTION ISOLATION LEVEL READ COMMITTED

- смотрим текущий уровень изоляции

```bash
show transaction isolation level;

 transaction_isolation 
-----------------------
 read committed
(1 row)
```

> Видим, что текущий статут изоляции - **read commited**

- начанаем новую транзакцию в обеих сессиях с дефолтным (не меняя) уровнем изоляции

```bash
begin;
```

- в первой сессии добавляем новую запись

```bash
insert into persons(first_name, second_name) values('sergey', 'sergeev');
```

- делаем select * from persons во второй сессии

```bash
select * from persons;

 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
(2 rows)
```

- видим ли мы новую запись и если да то почему?

> Не видим, так как уровень изоляции **read commited** позволяет видеть только те данные, которые были зафиксированы до начала **запроса**; мы никогда не увидит незафиксированных данных или изменений, внесённых в процессе выполнения запроса параллельными транзакциями

- завершаем первую транзакцию

```bash
commit;
```

- делаем select * from persons во второй сессии

```bash
select * from persons;

 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 rows)
```

- видим ли мы новую запись и если да то почему?

> Видим, так как мы зафиксировалы данные первой транзакции

- завершаем транзакцию во второй сессии

```bash
commit;
```

### TRANSACTION ISOLATION REPEATABLE READ

- начинаем новые, но уже **repeatable read** транзакции в обеих сессиях

```bash
set transaction isolation level repeatable read;
show transaction isolation level;
 transaction_isolation 
-----------------------
 repeatable read
(1 row)

begin;
```

- в первой сессии добавляем новую запись

```bash
insert into persons(first_name, second_name) values('sveta', 'svetova');
```

- делаем select * from persons во второй сессии

```bash
select * from persons;

 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 rows)
```

- видим ли мы новую запись и если да то почему?

> Не видим, так как уровень изоляции **repeatable read** позволяет видеть только те данные, которые были зафиксированы до начала **транзакции**, но не видны незафиксированные данные и изменения, произведённые другими транзакциями в процессе выполнения данной транзакции

- завершаем первую транзакцию - commit;

```bash
commit;
```

- делаем select * from persons во второй сессии

```bash
select * from persons;

----+------------+-------------
 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 rows)
```

- видим ли мы новую запись и если да то почему?

> Не видим, так как запрос в транзакции данного уровня видит снимок данных на момент начала **первого оператора** в транзакции, а не начала текущего оператора

- завершаем вторую транзакцию

```bash
commit;
```

- делаем select * from persons во второй сессии

```bash
select * from persons;
 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
  4 | sveta      | svetova
(4 rows)
```

- видим ли мы новую запись и если да то почему?

> Видим, так как мы завершили вторую транзакцию и теперь можем видеть зафиксированные данные первой транзакции

- останавливаем виртуальную машину, но не удаляем ее

> Полезная ссылка <https://postgrespro.ru/docs/postgrespro/13/transaction-iso>
