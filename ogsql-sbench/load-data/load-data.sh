#!/bin/bash

# threads is based on number of cpus
THDS=`nproc`

sysbench --threads=$THDS --rate=0 --report-interval=1 --db-driver=pgsql \
         --pgsql-host=$PGSQL_HOST --pgsql-port=$PGSQL_PORT --pgsql-db=$PGSQL_DB \
         --pgsql-user=$PGSQL_USER --pgsql-password=$PGSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_insert.lua --tables=$TABLES --table-size=$TABLE_SIZE prepare
