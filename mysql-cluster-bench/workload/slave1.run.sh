#!/bin/bash

scaleupto=$1
testcase=$2

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--mysql-socket=$MYSQL_SLAVE1_SOCK"
fi


for (( c=1; c<=$scaleupto; c*=2 ))
do
  $slave1cores sysbench --threads=$c --time=$time_per_tc --rate=0 --report-interval=1 \
           --db-driver=mysql --rand-type=uniform \
           --warmup-time=$warmup_per_tc \
           --mysql-host=$MYSQL_HOST --mysql-port=$MYSQL_SLAVE1_PORT $SOCK \
           --mysql-db=$MYSQL_DB \
           --mysql-user=$MYSQL_USER --mysql-password=$MYSQL_PASSWD \
           $testcase --tables=$TABLES --table-size=$TABLE_SIZE run
  sleep $scchangeover
done
