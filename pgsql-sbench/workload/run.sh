#!/bin/bash

THDS=$1
TC=$2

TASKSET="taskset -c "
IFS=',' read -ra client_cores <<< "$BENCHCORE"

if [[ $THDS -lt ${#client_cores[@]} ]]
then
  for (( i=0; i < $THDS; i++ ));
  do
    TASKSET="$TASKSET${client_cores[$i]},"
  done
  TASKSET=$(echo "$TASKSET" | sed "s,\,$,,")
else
  TASKSET="taskset -c $BENCHCORE"
fi

$TASKSET sysbench --threads=$THDS --time=$TIME_PER_TC --rate=0 --report-interval=5 \
         --db-driver=pgsql --rand-type=uniform \
	 --warmup-time=$WARMUP_PER_TC \
         --pgsql-host=$PGSQL_HOST --pgsql-port=$PGSQL_PORT \
         --pgsql-db=$PGSQL_DB \
         --pgsql-user=$PGSQL_USER --pgsql-password=$PGSQL_PASSWD \
         $TC --tables=$TABLES --table-size=$TABLE_SIZE run
