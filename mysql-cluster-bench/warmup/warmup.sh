#!/bin/bash

# threads is based on number of cpus
THDS=$1

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--mysql-socket=$MYSQL_ALLSOCK"
fi

# warm-up should run readonly workload to load pages into memory/buffer-pool.

$allcorebind sysbench --threads=$THDS --time=$2 --rate=0 --report-interval=5 --db-driver=mysql --rand-type=uniform \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_MASTER_PORT,$MYSQL_SLAVE1_PORT,$MYSQL_SLAVE2_PORT \
         $SOCK --mysql-db=$MYSQL_DB --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_read_only.lua --tables=$TABLES --table-size=$TABLE_SIZE run
