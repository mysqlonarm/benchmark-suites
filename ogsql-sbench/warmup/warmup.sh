#!/bin/bash

# threads is based on number of cpus
THDS=$1

# warm-up should run readonly workload to load pages into memory/buffer-pool.

sysbench --threads=$THDS --time=$2 --rate=0 --report-interval=5 --db-driver=pgsql --rand-type=uniform \
         --pgsql-host=$GSQL_HOST --pgsql-port=$GSQL_PORT --pgsql-db=$GSQL_DB \
         --pgsql-user=$GSQL_USER --pgsql-password=$GSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_point_select.lua --tables=$TABLES --table-size=$TABLE_SIZE run

sysbench --threads=$THDS --time=$2 --rate=0 --report-interval=5 --db-driver=pgsql --rand-type=uniform \
         --pgsql-host=$GSQL_HOST --pgsql-port=$GSQL_PORT --pgsql-db=$GSQL_DB \
         --pgsql-user=$GSQL_USER --pgsql-password=$GSQL_PASSWD \
         $SYSBENCH_LUA_SCRIPT_LOCATION/oltp_read_only.lua --tables=$TABLES --table-size=$TABLE_SIZE run
