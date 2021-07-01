# HW11

- создаем GCE инстанс e2-medium

```bash
gcloud beta compute instances create postgres-hw11 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
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

## Вариант 1 - индексы

- создаем таблицу orders и наполняем ее

```sql
create table orders(id int, user_id int, order_date date, status text, some_text text);

insert into orders(id, user_id, order_date, status, some_text)
select generate_series, (random() * 70), date'2021-01-01' + (random() * 300)::int as order_date
        , (array['returned', 'completed', 'placed', 'shipped'])[(random() * 4)::int]
        , concat_ws(' ', (array['go', 'space', 'sun', 'London'])[(random() * 5)::int]
        , (array['the', 'capital', 'of', 'Great', 'Britain'])[(random() * 6)::int]
        , (array['some', 'another', 'example', 'with', 'words'])[(random() * 6)::int]
        )
from generate_series(1, 5000000);
```

- проверяем количество строк в таблице

```sql
select count(*) from orders;
  count   
----------
 5000000
(1 row)
```

- смотрим размер таблицы

```sql
select pg_size_pretty(pg_table_size('orders'));
 pg_size_pretty
----------------
 313 MB
(1 row)
```

- смотрим план запроса

```sql
explain
select * from orders where id<1000000;
                                   QUERY PLAN                                    
---------------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..102562.06 rows=979501 width=34)
   Filter: (id < 1000000)
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(5 rows)
```

- выполним запрос

```sql
select * from orders where id<1000000;
Time: 1155.322 ms (00:01.155)
```

### Индекс на одно поле

- создаем индекс по колонке id

```sql
create unique index idx_ord_id on orders(id);
```

- смотртим размер индекса

```sql
select pg_size_pretty(pg_table_size('idx_ord_id'));
 pg_size_pretty 
----------------
 107 MB
(1 row)
```

- смотрим план запроса - будет ли использован индекс

```sql
explain
select * from orders where id<1000000;
                                    QUERY PLAN                                     
-----------------------------------------------------------------------------------
 Index Scan using idx_ord_id on orders  (cost=0.43..35740.14 rows=979469 width=34)
   Index Cond: (id < 1000000)
(2 rows)
```

> Используется Index Scan при выполнении запроса

- выполяем наш запрос и видим, что время выполнения запроса уменьшилось

```sql
select * from orders where id<1000000;
Time: 958.848 ms
```

### Индекс на несколько полей

- смотрим план запрос

```sql
explain
select order_date, status
from orders
where order_date between date'2021-01-01' and date'2021-02-01'
        and status = 'placed';
                                                        QUERY PLAN                                                         
---------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..90355.03 rows=128367 width=12)
   Workers Planned: 2
   ->  Parallel Seq Scan on orders  (cost=0.00..76518.33 rows=53486 width=12)
         Filter: ((order_date >= '2021-01-01'::date) AND (order_date <= '2021-02-01'::date) AND (status = 'placed'::text))
(4 rows)
```

> Видим, что будет использован Seq scan

- пробуем выполнить запрос и посмотреть затраченное время

```sql
select order_date, status
from orders
where order_date between date'2021-01-01' and date'2021-02-01'
        and status = 'placed';
Time: 617.706 ms
```

- теперь создадим индекс на несколько полей

```sql
create index idx_ord_order_date_status on orders(order_date, status);
```

- снова смотрим план запроса

```sql
explain
select order_date, status
from orders
where order_date between date'2021-01-01' and date'2021-02-01'
        and status = 'placed';
                                                       QUERY PLAN                                                        
-------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_ord_order_date_status on orders  (cost=0.43..9647.45 rows=128487 width=12)
   Index Cond: ((order_date >= '2021-01-01'::date) AND (order_date <= '2021-02-01'::date) AND (status = 'placed'::text))
(2 rows)
```

> Видим, что уже будет использован Index Only Scan

- выполним запрос и посмотрим на затраченное время

```sql
select order_date, status
from orders
where order_date between date'2021-01-01' and date'2021-02-01'
        and status = 'placed';
Time: 56.005 ms
```

> Как видим, время затраченное на выполнение запроса уменьшилось

### Индекс на часть таблицы

- создадим индекс на часть таблицы

```sql
create unique index idx_ord_id30 on orders(id) where id<30;
```

- посмотрим план запроса

```sql
explain        
select * from orders where id<30;
                                QUERY PLAN                                 
---------------------------------------------------------------------------
 Index Scan using idx_ord_id on orders  (cost=0.43..9.30 rows=29 width=63)
   Index Cond: (id < 30)
(2 rows)
```

> Запрос будет выполнен с помощью Index Scan

### Индекс для полнотекстового поиска

- создаем новую колонку типа tsvector и заполяем ее значениями из колонки some_text

```sql
- создаем колонку и апдейтим таблицу
alter table orders add column some_text_lexeme tsvector;
update orders set some_text_lexeme = to_tsvector(some_text);
```

- смотрим план запроса

```sql
explain
select some_text_lexeme
from orders
where some_text_lexeme @@ to_tsquery('britains');
                                   QUERY PLAN                                   
--------------------------------------------------------------------------------
 Gather  (cost=1000.00..1442452.56 rows=61137 width=14)
   Workers Planned: 2
   ->  Parallel Seq Scan on orders  (cost=0.00..1435338.86 rows=25474 width=14)
         Filter: (some_text_lexeme @@ to_tsquery('britains'::text))
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
(7 rows)
```

> Видим, что используется Parallel Seq Scan

- выполним запрос и посмотрим на время выполнения

```sql
select some_text
from orders
where some_text_lexeme @@ to_tsquery('britains');
Time: 11135.447 ms (00:11.135)
```

> долго)

- создадим индекс испольщующий метод доступа к индексам **gin**

```sql
CREATE INDEX search_index_ord ON orders USING GIN (some_text_lexeme);
```

- посмотрим план запроса

```sql
explain
select some_text_lexeme
from orders
where some_text_lexeme @@ to_tsquery('britains');
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Gather  (cost=8761.88..585617.83 rows=841500 width=29)
   Workers Planned: 2
   ->  Parallel Bitmap Heap Scan on orders  (cost=7761.88..500467.83 rows=350625 width=29)
         Recheck Cond: (some_text_lexeme @@ to_tsquery('britains'::text))
         ->  Bitmap Index Scan on search_index_ord  (cost=0.00..7551.50 rows=841500 width=0)
               Index Cond: (some_text_lexeme @@ to_tsquery('britains'::text))
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
(9 rows)
```

- выполним запрос

```sql
select some_text
from orders
where some_text_lexeme @@ to_tsquery('britains');
Time: 1177.572 ms (00:01.178)
```

> Время запроса уменьшилось

## Вариант 2 - join

- создадим еще одну таблицу customers для работы с join и наполним ее значениями от 1 до 100

```sql
create table customers(user_id int, passwd text);
insert into customers(user_id, passwd)
select generate_series, md5(random()::text) from generate_series(1, 100);
```

- посмотрим количество строк

```sql
select count(*) from customers;
 count 
-------
   100
(1 row)
```

- создадим индексы по полям user_id для каждой из таблиц

```sql
create unique index idx_cust_uid on customers(user_id);
create index idx_ord_uid on orders(user_id);
```

### Прямое соединение двух таблиц

- смотрим наш план запроса c выполнением при объединении двух таблиц по условию customers.user_id=orders.user_id

```sql
explain analyze
select a.user_id, b.order_date from customers a inner join orders b on a.user_id=b.user_id;
                                                       QUERY PLAN                                                        
-------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=3.25..216719.25 rows=5000000 width=8) (actual time=6.741..1683.352 rows=4964351 loops=1)
   Hash Cond: (b.user_id = a.user_id)
   ->  Seq Scan on orders b  (cost=0.00..147966.00 rows=5000000 width=8) (actual time=0.724..649.828 rows=5000000 loops=1)
   ->  Hash  (cost=2.00..2.00 rows=100 width=4) (actual time=6.000..6.002 rows=100 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 12kB
         ->  Seq Scan on customers a  (cost=0.00..2.00 rows=100 width=4) (actual time=5.952..5.968 rows=100 loops=1)
 Planning Time: 0.227 ms
 JIT:
   Functions: 11
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.069 ms, Inlining 0.000 ms, Optimization 0.444 ms, Emission 5.320 ms, Total 6.833 ms
 Execution Time: 1852.759 ms
(12 rows)

Time: 1828.744 ms (00:01.829)
```

> Как видим используется алгоритм Hash Join

### Левостороннее соединение двух таблиц

- смотрим наш план запроса c выполнением при объединении двух таблиц по условию customers.user_id=orders.user_id

```sql
explain analyze
select a.user_id, b.user_id from customers a left join orders b ON a.user_id=b.user_id;
                                                        QUERY PLAN                                                         
---------------------------------------------------------------------------------------------------------------------------
 Merge Left Join  (cost=994.38..188597.09 rows=5000000 width=8) (actual time=12.405..1449.082 rows=4964381 loops=1)
   Merge Cond: (a.user_id = b.user_id)
   ->  Sort  (cost=5.32..5.57 rows=100 width=4) (actual time=3.409..3.555 rows=100 loops=1)
         Sort Key: a.user_id
         Sort Method: quicksort  Memory: 29kB
         ->  Seq Scan on customers a  (cost=0.00..2.00 rows=100 width=4) (actual time=3.376..3.391 rows=100 loops=1)
   ->  Index Only Scan using idx_ord_uid on orders b  (cost=0.43..126091.27 rows=5000000 width=4) (actual time=0.022..913.458 rows=5000000 loops=1)
         Heap Fetches: 732165
 Planning Time: 0.167 ms
 JIT:
   Functions: 7
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.690 ms, Inlining 0.000 ms, Optimization 0.206 ms, Emission 2.997 ms, Total 3.893 ms
 Execution Time: 1616.485 ms
(14 rows)

Time: 1617.189 ms (00:01.617)
```

> В данном запросе используется самый быстрый алгоритм Merge Join

### Кросс соединение двух таблиц (n*m)

- сначала посмотрим на план запроса для кросс соединения

```sql
explain
select a.user_id, b.user_id from customers a cross join orders b;
                                            QUERY PLAN                                            
--------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.43..6376093.52 rows=500000000 width=8)
   ->  Index Only Scan using idx_ord_uid on orders b  (cost=0.43..126091.27 rows=5000000 width=4)
   ->  Materialize  (cost=0.00..2.50 rows=100 width=4)
         ->  Seq Scan on customers a  (cost=0.00..2.00 rows=100 width=4)
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
(7 rows)

Time: 1.455 ms
```

- выполним запрос с explain analyze

```sql
explain analyze
select a.user_id, b.user_id from customers a cross join orders b;
                                                                     QUERY PLAN                                                                      
-----------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.43..6376093.52 rows=500000000 width=8) (actual time=29.335..69785.076 rows=500000000 loops=1)
   ->  Index Only Scan using idx_ord_uid on orders b  (cost=0.43..126091.27 rows=5000000 width=4) (actual time=0.025..1054.425 rows=5000000 loops=1)
         Heap Fetches: 732165
   ->  Materialize  (cost=0.00..2.50 rows=100 width=4) (actual time=0.000..0.005 rows=100 loops=5000000)
         ->  Seq Scan on customers a  (cost=0.00..2.00 rows=100 width=4) (actual time=29.298..29.313 rows=100 loops=1)
 Planning Time: 0.116 ms
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.576 ms, Inlining 3.800 ms, Optimization 16.495 ms, Emission 8.865 ms, Total 29.736 ms
 Execution Time: 86468.906 ms
(11 rows)

Time: 86469.622 ms (01:26.470)
```

> Использован алгоритм Nested Loop

### Полное соединение двух таблиц

- создадим и выполним запрос, чтобы найти те строки, для которых ненашлось соответствия в противоположной таблице

```sql
explain analyze
select a.user_id, b.user_id from customers a full join orders b ON a.user_id=b.user_id WHERE a.user_id is null or b.user_id is null;
                                                                    QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Merge Full Join  (cost=0.57..188605.17 rows=1 width=8) (actual time=1.610..1185.438 rows=35679 loops=1)
   Merge Cond: (a.user_id = b.user_id)
   Filter: ((a.user_id IS NULL) OR (b.user_id IS NULL))
   Rows Removed by Filter: 4964351
   ->  Index Only Scan using idx_cust_uid on customers a  (cost=0.14..13.64 rows=100 width=4) (actual time=0.012..0.186 rows=100 loops=1)
         Heap Fetches: 100
   ->  Index Only Scan using idx_ord_uid on orders b  (cost=0.43..126091.27 rows=5000000 width=4) (actual time=0.015..808.199 rows=5000000 loops=1)
         Heap Fetches: 732165
 Planning Time: 0.200 ms
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.380 ms, Inlining 0.000 ms, Optimization 0.111 ms, Emission 1.392 ms, Total 1.883 ms
 Execution Time: 1187.213 ms
(14 rows)
```

> Использован алгоритм Merge Full Join

### Использование разных типов соединений

- в данном запросы мы объединяем прямым соединеним таблицу customers саму с собой и левосторонним соединеним с таблицей orders

```sql
explain analyze
select a.user_id from customers a inner join customers b on a.user_id=b.user_id
left join orders c ON a.user_id=c.user_id;
                                                                     QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Merge Left Join  (cost=999.00..188601.72 rows=5000000 width=4) (actual time=14.258..1347.645 rows=4964381 loops=1)
   Merge Cond: (a.user_id = c.user_id)
   ->  Sort  (cost=9.95..10.20 rows=100 width=4) (actual time=6.195..6.320 rows=100 loops=1)
         Sort Key: a.user_id
         Sort Method: quicksort  Memory: 29kB
         ->  Hash Join  (cost=3.25..6.62 rows=100 width=4) (actual time=6.149..6.181 rows=100 loops=1)
               Hash Cond: (a.user_id = b.user_id)
               ->  Seq Scan on customers a  (cost=0.00..2.00 rows=100 width=4) (actual time=0.014..0.021 rows=100 loops=1)
               ->  Hash  (cost=2.00..2.00 rows=100 width=4) (actual time=6.126..6.128 rows=100 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 12kB
                     ->  Seq Scan on customers b  (cost=0.00..2.00 rows=100 width=4) (actual time=6.080..6.097 rows=100 loops=1)
   ->  Index Only Scan using idx_ord_uid on orders c  (cost=0.43..126091.27 rows=5000000 width=4) (actual time=0.023..809.900 rows=5000000 loops=1)
         Heap Fetches: 732165
 Planning Time: 0.247 ms
 JIT:
   Functions: 15
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.262 ms, Inlining 0.000 ms, Optimization 0.299 ms, Emission 5.527 ms, Total 7.089 ms
 Execution Time: 1516.461 ms
(19 rows)
```

## Структуры таблиц

- customers

```sql
\d customers
              Table "public.customers"
 Column  |  Type   | Collation | Nullable | Default 
---------+---------+-----------+----------+---------
 user_id | integer |           |          | 
 passwd  | text    |           |          | 
Indexes:
    "idx_cust_uid" UNIQUE, btree (user_id)
```

- orders

```sql
\d orders
                    Table "public.orders"
      Column      |   Type   | Collation | Nullable | Default 
------------------+----------+-----------+----------+---------
 id               | integer  |           |          | 
 user_id          | integer  |           |          | 
 order_date       | date     |           |          | 
 status           | text     |           |          | 
 some_text        | text     |           |          | 
 some_text_lexeme | tsvector |           |          | 
Indexes:
    "idx_ord_id" UNIQUE, btree (id)
    "idx_ord_id30" UNIQUE, btree (id) WHERE id < 30
    "idx_ord_order_date_status" btree (order_date, status)
    "idx_ord_uid" btree (user_id)
    "search_index_ord" gin (some_text_lexeme)
```

### Метрики

- показать активность в кластере со статусами

```sql
select client_addr, usename, datname, state, count(*) from pg_stat_activity group by 1, 2, 3, 4 order by 5 desc;
```

- показать сколько индексов в кеше

```sql
select sum(idx_blks_read) as idx_read, sum(idx_blks_hit)  as idx_hit, (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio from pg_statio_user_indexes;
```

- показать активные запросы

```sql
select pid, age(clock_timestamp(), query_start), usename, query from  pg_stat_activity where query != '<IDLE>' and query not ilike '%pg_stat_activity%' order by query_start desc;
```
