#!/bin/bash

THDS=$1

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--mysql-socket=$MYSQL_MASTER_SOCK"
fi

$allcorebind sysbench --threads=$THDS --rate=0 --report-interval=1 --db-driver=mysql \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_MASTER_PORT $SOCK --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_insert.lua --tables=$TABLES --table-size=$TABLE_SIZE prepare
