# HW12

- создаем GCE инстанс e2-medium

```bash
gcloud beta compute instances create postgres-hw12 \
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

- скачиваем демонстрационную базу данных

```bash
wget https://edu.postgrespro.ru/demo-big.zip
unzip demo-big.zip
```

- импортируем

```bash
sudo -u postgres psql < demo-big-20170815.sql
```

- наши таблицы

```sql
\dt
               List of relations
  Schema  |      Name       | Type  |  Owner   
----------+-----------------+-------+----------
 bookings | aircrafts_data  | table | postgres
 bookings | airports_data   | table | postgres
 bookings | boarding_passes | table | postgres
 bookings | bookings        | table | postgres
 bookings | flights         | table | postgres
 bookings | seats           | table | postgres
 bookings | ticket_flights  | table | postgres
 bookings | tickets         | table | postgres
(8 rows)
```

- для секционирования выберем таблицу - Booking

```sql
\d bookings
                        Table "bookings.bookings"
    Column    |           Type           | Collation | Nullable | Default 
--------------+--------------------------+-----------+----------+---------
 book_ref     | character(6)             |           | not null | 
 book_date    | timestamp with time zone |           | not null | 
 total_amount | numeric(10,2)            |           | not null | 
Indexes:
    "bookings_pkey" PRIMARY KEY, btree (book_ref)
Referenced by:
    TABLE "tickets" CONSTRAINT "tickets_book_ref_fkey" FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)
```

- посмотрим на максимальное и минимальное значения для определения наших будущих секций

```sql
select min(book_date),max(book_date) from bookings;
          min           |          max           
------------------------+------------------------
 2016-07-20 18:16:00+00 | 2017-08-15 15:00:00+00
(1 row)
```

- количество строк

```sql
select count(*) from bookings.bookings;
  count  
---------
 2111110
(1 row)
```

- выполним тестовый запрос и посмотрим на время исполнения

```sql
EXPLAIN ANALYZE
SELECT * FROM bookings.bookings WHERE book_date BETWEEN date'2016-11-01' AND date'2017-03-01'-1;
                                                    QUERY PLAN                                                     
-------------------------------------------------------------------------------------------------------------------
 Seq Scan on bookings  (cost=0.00..45113.65 rows=668031 width=21) (actual time=2.007..485.374 rows=656954 loops=1)
   Filter: ((book_date >= '2016-11-01'::date) AND (book_date <= '2017-02-28'::date))
   Rows Removed by Filter: 1454156
 Planning Time: 15.246 ms
 Execution Time: 511.879 ms
(5 rows)
```

- создаем новый объект для секционирования

```sql
CREATE TABLE bookings.bookings_part (
    book_ref character(6) NOT NULL,
    book_date timestamp with time zone NOT NULL,
    total_amount numeric(10,2) NOT NULL
) PARTITION BY RANGE(book_date);
```

- создаем таблицы с разбивкой по месяцам

```sql
CREATE TABLE bookings.bookings_part_2016_07 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-07-01') TO ('2016-08-01');
CREATE TABLE bookings.bookings_part_2016_08 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-08-01') TO ('2016-09-01');
CREATE TABLE bookings.bookings_part_2016_09 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-09-01') TO ('2016-10-01');
CREATE TABLE bookings.bookings_part_2016_10 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-10-01') TO ('2016-11-01');
CREATE TABLE bookings.bookings_part_2016_11 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-11-01') TO ('2016-12-01');
CREATE TABLE bookings.bookings_part_2016_12 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-12-01') TO ('2017-01-01');
CREATE TABLE bookings.bookings_part_2017_01 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-01-01') TO ('2017-02-01');
CREATE TABLE bookings.bookings_part_2017_02 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-02-01') TO ('2017-03-01');
CREATE TABLE bookings.bookings_part_2017_03 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-03-01') TO ('2017-04-01');
CREATE TABLE bookings.bookings_part_2017_04 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-04-01') TO ('2017-05-01');
CREATE TABLE bookings.bookings_part_2017_05 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-05-01') TO ('2017-06-01');
CREATE TABLE bookings.bookings_part_2017_06 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-06-01') TO ('2017-07-01');
CREATE TABLE bookings.bookings_part_2017_07 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-07-01') TO ('2017-08-01');
CREATE TABLE bookings.bookings_part_2017_08 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2017-08-01') TO ('2017-09-01');
```

- копируем данные из таблицы booking в нашу новую секционированную таблицу bookings_part

```sql
INSERT INTO bookings.bookings_part (book_ref,book_date,total_amount) SELECT book_ref,book_date,total_amount FROM bookings.bookings;
```

- выполняем запрос уже по секционированной таблице

```sql
EXPLAIN ANALYZE
SELECT * FROM bookings.bookings_part WHERE book_date BETWEEN date'2016-11-01' AND date'2017-03-01'-1;
                                                                     QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Append  (cost=0.00..48404.54 rows=656777 width=21) (actual time=0.011..166.162 rows=656954 loops=1)
   Subplans Removed: 10
   ->  Seq Scan on bookings_part_2016_11 bookings_part_1  (cost=0.00..3535.55 rows=165404 width=21) (actual time=0.011..31.224 rows=165437 loops=1)
         Filter: ((book_date >= '2016-11-01'::date) AND (book_date <= '2017-02-28'::date))
   ->  Seq Scan on bookings_part_2016_12 bookings_part_2  (cost=0.00..3661.35 rows=171256 width=21) (actual time=0.013..31.888 rows=171290 loops=1)
         Filter: ((book_date >= '2016-11-01'::date) AND (book_date <= '2017-02-28'::date))
   ->  Seq Scan on bookings_part_2017_01 bookings_part_3  (cost=0.00..3659.09 rows=171172 width=21) (actual time=0.013..32.337 rows=171206 loops=1)
         Filter: ((book_date >= '2016-11-01'::date) AND (book_date <= '2017-02-28'::date))
   ->  Seq Scan on bookings_part_2017_02 bookings_part_4  (cost=0.00..3303.97 rows=148935 width=21) (actual time=0.014..28.940 rows=149021 loops=1)
         Filter: ((book_date >= '2016-11-01'::date) AND (book_date <= '2017-02-28'::date))
         Rows Removed by Filter: 5577
 Planning Time: 0.299 ms
 Execution Time: 188.434 ms
(13 rows)
```

> Видим, что время обработки запроса уменьшилось, так как мы обращается не ко всей таблице, а только к необходимых секциям, где содержатся необходимые нам значения
