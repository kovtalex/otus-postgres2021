# HW2

- создаем виртуальную машину c Ubuntu 20.04 LTS в GCE типа e2-medium в default VPC в любом регионе и зоне, например us-central1-a

```bash
gcloud beta compute instances create postgres-hw2 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--restart-on-failure
```

- ставим на нее PostgreSQL через sudo apt

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql
```

- проверяем, что кластер запущен через sudo -u postgres pg_lsclusters

```bash
sudo -u postgres pg_lsclusters

Ver Cluster Port Status Owner    Data directory              Log file
13  main    5432 online postgres /var/lib/postgresql/13/main /var/log/postgresql/postgresql-13-main.log
```

- зайдите из под пользователя postgres в psql и сделайте произвольную таблицу с произвольным содержимым

```bash
sudo -u postgres psql

create table test(c1 text);
insert into test values('1');
\q
```

- остановим postgres например через sudo -u postgres pg_ctlcluster 13 main stop

```bash
sudo -u postgres pg_ctlcluster 13 main stop

Warning: stopping the cluster using pg_ctlcluster will mark the systemd unit as failed. Consider using systemctl:
  sudo systemctl stop postgresql@13-main
```

- создадим новый standard persistent диск GKE через Compute Engine -> Disks в том же регионе и зоне что GCE инстанс размером например 10GB
- добавим свеже-созданный диск к виртуальной машине - надо зайти в режим ее редактирования и дальше выбрать пункт attach existing disk
- проинициализируем диск согласно инструкции и подмонтируем файловую систему, только незабываем менять имя диска на актуальное, в вашем случае это скорее всего будет /dev/sdb - <https://www.digitalocean.com/community/tutorials/how-to-partition-and-format-storage-devices-in-linux>

```bash
lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0     7:0    0  55.5M  1 loop /snap/core18/1997
loop1     7:1    0 227.8M  1 loop /snap/google-cloud-sdk/180
loop2     7:2    0  67.6M  1 loop /snap/lxd/20326
loop3     7:3    0  32.3M  1 loop /snap/snapd/11588
sda       8:0    0    10G  0 disk 
├─sda1    8:1    0   9.9G  0 part /
├─sda14   8:14   0     4M  0 part 
└─sda15   8:15   0   106M  0 part /boot/efi
sdb       8:16   0    10G  0 disk 

sudo parted /dev/sdb mklabel gpt
sudo parted -a opt /dev/sda mkpart primary ext4 0% 100%

lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0     7:0    0  55.5M  1 loop /snap/core18/1997
loop1     7:1    0 227.8M  1 loop /snap/google-cloud-sdk/180
loop2     7:2    0  67.6M  1 loop /snap/lxd/20326
loop3     7:3    0  32.3M  1 loop /snap/snapd/11588
sda       8:0    0    10G  0 disk 
├─sda1    8:1    0   9.9G  0 part /
├─sda14   8:14   0     4M  0 part 
└─sda15   8:15   0   106M  0 part /boot/efi
sdb       8:16   0    10G  0 disk 
└─sdb1    8:17   0    10G  0 part

sudo mkfs.ext4 -L datapartition /dev/sdb1
mke2fs 1.45.5 (07-Jan-2020)
Discarding device blocks: done                            
Creating filesystem with 2620928 4k blocks and 655360 inodes
Filesystem UUID: 1c184b88-ebac-462f-838b-09e1bc880d86
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done

sudo lsblk --fs
NAME    FSTYPE   LABEL           UUID                                 FSAVAIL FSUSE% MOUNTPOINT
loop0   squashfs                                                            0   100% /snap/core18/1997
loop1   squashfs                                                            0   100% /snap/google-cloud-sdk/180
loop2   squashfs                                                            0   100% /snap/lxd/20326
loop3   squashfs                                                            0   100% /snap/snapd/11588
sda                                                                                  
├─sda1  ext4     cloudimg-rootfs 730cc5fb-b160-496c-a7bf-b4ca3ed12ebf    9.2G     0% /mnt/data
├─sda14                                                                              
└─sda15 vfat     UEFI            7010-20C8                              96.6M     7% /boot/efi
sdb                                                                                  
└─sdb1  ext4     datapartition   1c184b88-ebac-462f-838b-09e1bc880d86    9.2G     0% /mnt/data

sudo mkdir -p /mnt/data
sudo mount -o defaults /dev/sdb1 /mnt/data

sudo nano /etc/fstab
LABEL=datapartition /mnt/data ext4 defaults 0 2
```

- сделаем пользователя postgres владельцем /mnt/data - chown -R postgres:postgres /mnt/data/

```bash
chown -R postgres:postgres /mnt/data/
```

- перенесем содержимое /var/lib/postgres/13 в /mnt/data - mv /var/lib/postgresql/13 /mnt/data

```bash
sudo mv /var/lib/postgresql/13 /mnt/data
```

- попытаемся запустить кластер - sudo -u postgres pg_ctlcluster 13 main start

```bash
sudo -u postgres pg_ctlcluster 13 main start

Error: /var/lib/postgresql/13/main is not accessible or does not exist
```

> Кластер не запустился, так как мы перенесли данные postresql

- найдем конфигурационный параметр в файлах раположенных в /etc/postgresql/13/main, который надо поменять и поменяем его

> В файле /etc/postgresql/13/main/postgresql.conf в переменной data_directory меняем путь каталога (в котором хранятся данные postgresql) с /var/lib/postgresql/13/main на /mnt/data/13/main  
> который находится на нашем новом проинициализированном диске

- попытаемся запустить кластер - sudo -u postgres pg_ctlcluster 13 main start

```bash
sudo -u postgres pg_ctlcluster 13 main start

Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@13-main
```

- кластер успешно запустился
- зайдем через через psql и проверим содержимое ранее созданной таблицы

```bash
sudo -u postgres psql

select c1 from test;
 c1 
----
 1
(1 row)
```

## Задание со *

- не удаляя существующий GCE инстанс сделаем новый

```bash
gcloud beta compute instances create postgres-hw2-star \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--restart-on-failure
```

- поставим на него PostgreSQL

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql
```

- удалим файлы с данными из /var/lib/postgres

```bash
sudo -u postgres pg_ctlcluster 13 main stop
Warning: stopping the cluster using pg_ctlcluster will mark the systemd unit as failed. Consider using systemctl:
  sudo systemctl stop postgresql@13-main

sudo rm -rf /var/lib/postgres
```

- перемонтируем внешний диск, который сделали ранее от первой виртуальной машины ко второй

> останавливаем первую виртуальную машину и отключаем от нее наш диск  
> подключаем диск к новом виртуальной машине

```bash
sudo lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0     7:0    0  55.5M  1 loop /snap/core18/1997
loop1     7:1    0 227.8M  1 loop /snap/google-cloud-sdk/180
loop2     7:2    0  67.6M  1 loop /snap/lxd/20326
loop3     7:3    0  32.3M  1 loop /snap/snapd/11588
sda       8:0    0    10G  0 disk 
├─sda1    8:1    0   9.9G  0 part /
├─sda14   8:14   0     4M  0 part 
└─sda15   8:15   0   106M  0 part /boot/efi
sdb       8:16   0    10G  0 disk 
└─sdb1    8:17   0    10G  0 part

sudo mkdir -p /mnt/data
sudo mount -o defaults /dev/sdb1 /mnt/data

sudo nano /etc/fstab
LABEL=datapartition /mnt/data ext4 defaults 0 2
```

- В файле /etc/postgresql/13/main/postgresql.conf в переменной data_directory меняем путь на /mnt/data/13/main

- запускаем PostgreSQL на второй машине так, чтобы он работал с данными на внешнем диске

```bash
sudo -u postgres pg_ctlcluster 13 main start

Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@13-main

sudo -u postgres psql

select c1 from test;
 c1 
----
 1
(1 row)
```

> Видим нашу табличку
