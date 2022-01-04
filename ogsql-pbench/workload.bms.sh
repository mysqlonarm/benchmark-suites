#! /bin/bash

#set -x

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] ; then
    echo 'usage: combi_1 <test-case-name> [skipload]'
    exit 1
fi

TESTCASE=$1
SKIPLOAD=0
if [ "$2" = "skipload" ]; then
	SKIPLOAD=1
fi

export GSQL_HOST="localhost"
export GSQL_PORT=5432
export GSQL_SOCK="/tmp/n1.sock"
export GSQL_USER="root"
export GSQL_DB=$TESTCASE
export GSQL_PASSWD="root"

# tc combination: 120/60/10/10/0
# workload-warmup time
warmuptime=120
# test-case execution time
export TIME_PER_TC=60
# test-case warmup time
export WARMUP_PER_TC=10
# sleep between 2 scalability
scchangeover=10
# sleep between 2 sub-testcase run (like while switching from rw -> tpcb)
tcchangeover=120

export SCALE=5000
#export TC_TO_RUN="ro rw tpcb"
export TC_TO_RUN="ro rw"

# x86-bms-server-conf (4 sysbench cores, 28 server cores, 1 numa nodes)
#export BENCHCORE="0,36,1,37"
# arm-bms-server-conf (4 sysbench cores, 28 server cores, 1 numa nodes)
#export BENCHCORE="0,1,2,3"

# x86-bms-server-conf (8 sysbench cores, 56 server cores, 2 numa nodes)
#export BENCHCORE="0,18,36,54,1,19,37,55"
# arm-bms-server-conf (8 sysbench cores, 56 server cores, 2 numa nodes)
#export BENCHCORE="0,32,1,33,2,34,3,35"

# x86-bms-conf (12 sysbench cores, 60 server cores, 2 numa nodes)
#export BENCHCORE="0,18,36,54,1,19,37,55,2,20,38,56"
# arm-bms-conf (16 sysbench cores, 112 server cores, 4 numa nodes)
#export BENCHCORE="0,64,32,96,1,65,33,97,2,66,34,98,3,67,35,99"

# x86-bms-conf (6 sysbench cores, 22 server cores, 2 numa nodes)
#export BENCHCORE="0,18,36,1,19,37"
#export BENCHCORE="0,24,1,25,2,26"
# arm-bms-conf (8 sysbench cores, 56 server cores, 2 numa nodes)
#export BENCHCORE="0,32,1,33,2,34,3,35"

#export BENCHCORE="0,1,2"
#export BENCHCORE="0,24,1,25,2,26"
#export BENCHCORE="0,24,48,72,1,25,49,73,2,26,50,74"
#export BENCHCORE="0-23"
#export BENCHCORE="0-47"
export BENCHCORE="0-95"


if [ -z $BENCHCORE ]; then
  echo 'cpu affinity for running client is not set'
  exit 1
fi

# core on target machine
servercore=128

#-------------------------------------------------------------------------------------
# execution start. avoid modifying anything post this point. All your enviornment
# variable should be set above.

#=======================
# step-0: check for presence of existing result directory
#=======================
if [ -d "output/$TESTCASE" ]; then
  echo 'previous run for same test-case is present. please remove it and restart'
  exit 1
fi
rm -rf output/$TESTCASE
mkdir -p output/$TESTCASE

#=======================
# step-1
#=======================

export GSQL_BASE_DIR="/opt/projects/ogauss/non-forked-ogauss/installed"
export GSQLCMD="$GSQL_BASE_DIR/bin/gsql -d postgres -U $GSQL_USER -W $GSQL_PASSWD"
export PGBENCH="$GSQL_BASE_DIR/bin/pgbench -U $GSQL_USER -W $GSQL_PASSWD"

if [ ! -f "$GSQL_BASE_DIR/bin/gsql" ]; then
    echo "psql not found. Check/Set 'GSQL_BASE_DIR'"
    exit 1
fi

if [ ! -f "$GSQL_BASE_DIR/bin/pgbench" ]; then
    echo "pgbench not found. Check/Set 'GSQL_BASE_DIR'"
    exit 1
fi

# if there is no pgsql client on local machine then adjust GSQL_BASE_DIR accordingly.
if [ $SKIPLOAD -eq 0 ]; then
  $GSQLCMD -c "drop database if exists $GSQL_DB;" &> /dev/null
  $GSQLCMD -c "create database $GSQL_DB;" &> /dev/null
fi

#=======================
# step-2: load data
#=======================

if [ $SKIPLOAD -eq 0 ]; then
  echo -e "\n\n"
  echo "Starting to load tables"
  $PGBENCH -i -s $SCALE $GSQL_DB 
  $GSQLCMD -c "checkpoint" &> /dev/null
fi

#=======================
# step-3: warmup <usage: script-name <warm-uptime>
#=======================

if [[ $warmuptime -ne 0 ]]; then
  echo 'Warming up DB'
  #$GSQLCMD -d $GSQL_DB -c "create extension pg_prewarm;" &>> output/$TESTCASE/warmup.out
  #$GSQLCMD -d $GSQL_DB -c "select pg_prewarm('pgbench_branches'::regclass);" &>> output/$TESTCASE/warmup.out
  #$GSQLCMD -d $GSQL_DB -c "select pg_prewarm('pgbench_history'::regclass);" &>> output/$TESTCASE/warmup.out
  #$GSQLCMD -d $GSQL_DB -c "select pg_prewarm('pgbench_tellers'::regclass);" &>> output/$TESTCASE/warmup.out
  #$GSQLCMD -d $GSQL_DB -c "select pg_prewarm('pgbench_accounts'::regclass);" &>> output/$TESTCASE/warmup.out
  $PGBENCH $GSQL_DB -T $warmuptime -S -c $servercore -j $servercore -M prepared -P 5 -r &>> output/$TESTCASE/warmup.out
  echo -e "\n\n"
fi

#=======================
# step-4
# actual workload. <usage: script-name <threads> <time>>
#=======================
# workload will auto-calculate number of threads to use based on core
# if core = 16 then scalability would be < 16 * 10 (160). So test-case will
# run for 1/2/4/8/16/32/64/128 only.
NCORE=$(( 12*$servercore ))

#---- select-only
count=1
if [[ $TC_TO_RUN =~ "ro" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do

    TASKSET="taskset -c "
    IFS=',' read -ra client_cores <<< "$BENCHCORE"
    if [[ $count -lt ${#client_cores[@]} ]]
    then
      for (( i=0; i < $count; i++ ));
      do
        TASKSET="$TASKSET${client_cores[$i]},"
      done
      TASKSET=$(echo "$TASKSET" | sed "s,\,$,,")
    else
      TASKSET="taskset -c $BENCHCORE"
    fi

    echo "Running select-only with $count threads"
    $TASKSET $PGBENCH $GSQL_DB -T $TIME_PER_TC -S -c $count -j $count -M prepared -P 5 -r &>> output/$TESTCASE/pgbench-ro.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping read-only selection"
fi

#---- simple-update
count=1
if [[ $TC_TO_RUN =~ "rw" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do

    TASKSET="taskset -c "
    IFS=',' read -ra client_cores <<< "$BENCHCORE"
    if [[ $count -lt ${#client_cores[@]} ]]
    then
      for (( i=0; i < $count; i++ ));
      do
        TASKSET="$TASKSET${client_cores[$i]},"
      done
      TASKSET=$(echo "$TASKSET" | sed "s,\,$,,")
    else
      TASKSET="taskset -c $BENCHCORE"
    fi

    echo "Running simple-update with $count threads"
    $TASKSET $PGBENCH $GSQL_DB -T $TIME_PER_TC -c $count -j $count -M prepared -P 5 -r &>> output/$TESTCASE/pgbench-rw.out
    count=$(( count * 2 ))
    sleep $scchangeover
  done
  sleep $tcchangeover
else
  echo "Skipping simple-update selection"
fi

#---- tpcb-like
count=1
if [[ $TC_TO_RUN =~ "tpcb" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do

    TASKSET="taskset -c "
    IFS=',' read -ra client_cores <<< "$BENCHCORE"
    if [[ $count -lt ${#client_cores[@]} ]]
    then
      for (( i=0; i < $count; i++ ));
      do
        TASKSET="$TASKSET${client_cores[$i]},"
      done
      TASKSET=$(echo "$TASKSET" | sed "s,\,$,,")
    else
      TASKSET="taskset -c $BENCHCORE"
    fi

    echo "Running tpcb-like with $count threads"
    $TASKSET $PGBENCH $GSQL_DB -T $TIME_PER_TC -b tpcb-like -c $count -j $count -M prepared -P 5 -r &>> output/$TESTCASE/pgbench-tcpb.out
    count=$(( count * 2 ))
  done
  sleep $tcchangeover
else
  echo "Skipping tcpb selection"
fi

echo "Workload processed"
echo -e "\n\n"

#=======================
# step-5
# processing result. <usage: script-name $TESTCASE>
#=======================
echo "Processing result"
./process-result/presult.sh $TESTCASE

$GSQLCMD -c "checkpoint" 2> /dev/null
