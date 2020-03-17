#!/bin/bash

# threads is based on number of cpus
THDS=`nproc`

sysbench --threads=$THDS --rate=0 --report-interval=1 --db-driver=mysql \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         /usr/share/sysbench/oltp_insert.lua --tables=$TABLES --table-size=$TABLE_SIZE prepare
