#!/bin/bash

THDS=$1
TIME=$2
TC=$3

sysbench --threads=$THDS --time=$TIME --rate=0 --report-interval=5 --db-driver=mysql --rand-type=uniform \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         $TC --tables=$TABLES --table-size=$TABLE_SIZE run
