# HW3

- создаем виртуальную машину c Ubuntu 20.04

```bash
gcloud beta compute instances create postgres-hw3 \
--machine-type=n1-standard-1 \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--tags=postgres \
--restart-on-failure
```

- подключаемся к VM и устанавливаем Docker Engine

```bash
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

- создадим каталог /var/lib/postgres

```bash
sudo mkdir -p /var/lib/postgres
```

- развернем контейнер с PostgreSQL 13 и смонтируем в него /var/lib/postgres

```bash
sudo docker network create pg-net
sudo docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:13

sudo docker ps
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                                       NAMES
20d2723b7a0e   postgres:13   "docker-entrypoint.s…"   6 seconds ago   Up 4 seconds   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   pg-server
```

- развернем контейнер с клиентом postgres, подключимся из него к контейнеру с сервером и сделаем таблицу с парой строк

```bash
sudo docker run -it --rm --network pg-net --name pg-client postgres:13 psql -h pg-server -U postgres
```

```sql
create table test(i int);
insert into test values(1);
insert into test values(2);
insert into test values(3);
select i from test;
 i 
---
 1
 2
 3
(3 rows)
```

- подключимся к контейнеру с сервером с ноутбука/комьютера вне инстансов GCP

```bash
psql -h 35.205.235.158 -U postgres
```

- удалим контейнер с сервера

```bash
sudo docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                                       NAMES
b47adb670dc2   postgres:13   "docker-entrypoint.s…"   6 minutes ago   Up 6 minutes   5432/tcp                                    pg-client
20d2723b7a0e   postgres:13   "docker-entrypoint.s…"   7 minutes ago   Up 7 minutes   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   pg-server

sudo docker rm -f pg-server
```

- создадим его заново

```bash
sudo docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:13
```

- подключимся снова из контейнера с клиентом к контейнеру с сервером

```bash
sudo docker run -it --rm --network pg-net --name pg-client postgres:13 psql -h pg-server -U postgres
```

- проверим, что данные остались на месте

```sql
select i from test;
 i 
---
 1
 2
 3
(3 rows)
```
