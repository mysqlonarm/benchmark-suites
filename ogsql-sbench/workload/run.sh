#!/bin/bash

THDS=$1
TC=$2

TASKSET="taskset -c $BENCHCORE"

$TASKSET sysbench --threads=$THDS --time=$TIME_PER_TC --rate=0 --report-interval=5 \
         --db-driver=pgsql --rand-type=uniform \
	 --warmup-time=$WARMUP_PER_TC \
         --pgsql-host=$GSQL_HOST --pgsql-port=$GSQL_PORT \
         --pgsql-db=$GSQL_DB \
         --pgsql-user=$GSQL_USER --pgsql-password=$GSQL_PASSWD \
         $TC --tables=$TABLES --table-size=$TABLE_SIZE run
