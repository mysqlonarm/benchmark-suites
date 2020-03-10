#!/bin/bash

# threads is based on number of cpus
THDS=`nproc`

# warm-up should run readonly workload to load pages into memory/buffer-pool.

sysbench --threads=$THDS --time=$1 --rate=0 --report-interval=5 --db-driver=mysql --rand-type=uniform \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         --test=/usr/share/sysbench/oltp_read_only.lua --tables=$TABLES --table-size=$TABLE_SIZE run
