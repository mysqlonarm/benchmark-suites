#!/bin/bash

# threads is based on number of cpus
THDS=$1

# warm-up should run readonly workload to load pages into memory/buffer-pool.

sysbench --threads=$THDS --time=$2 --rate=0 --report-interval=5 --db-driver=pgsql --rand-type=uniform \
         --pgsql-host=$PGSQL_HOST --pgsql-port=$PGSQL_PORT --pgsql-db=$PGSQL_DB \
         --pgsql-user=$PGSQL_USER --pgsql-password=$PGSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_read_only.lua --tables=$TABLES --table-size=$TABLE_SIZE run
