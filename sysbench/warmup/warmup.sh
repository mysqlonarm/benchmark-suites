#!/bin/bash

# threads is based on number of cpus
THDS=$1

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--mysql-socket=$MYSQL_SOCK"
fi

# warm-up should run readonly workload to load pages into memory/buffer-pool.

sysbench --threads=$THDS --time=$2 --rate=0 --report-interval=5 --db-driver=mysql --rand-type=uniform \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT $SOCK --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         /usr/share/sysbench/oltp_read_only.lua --tables=$TABLES --table-size=$TABLE_SIZE run
