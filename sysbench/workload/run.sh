#!/bin/bash

THDS=$1
TC=$2

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--mysql-sock=$MYSQL_SOCK"
fi


TASKSET="taskset -c "
IFS=',' read -ra client_cores <<< "$BENCHCORE"

if [[ $THDS -lt ${#client_cores[@]} ]]
then
  echo "--- generating $THDS - ${#client_cores[@]}"
  for (( i=0; i < $THDS; i++ ));
  do
    TASKSET="$TASKSET${client_cores[$i]},"
  done
  TASKSET=$(echo "$TASKSET" | sed "s,\,$,,")
else
  TASKSET="taskset -c $BENCHCORE"
fi

$TASKSET sysbench --threads=$THDS --time=$TIME_PER_TC --rate=0 --report-interval=5 \
         --db-driver=mysql --rand-type=uniform \
	 --warmup-time=$WARMUP_PER_TC \
         --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_PORT $SOCK \
         --mysql-db=$MYSQL_DB \
         --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
         $TC --tables=$TABLES --table-size=$TABLE_SIZE run
