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

export PGSQL_HOST="localhost"
export PGSQL_PORT=5432
export PGSQL_SOCK="/tmp/n1.sock"
export PGSQL_USER="root"
export PGSQL_DB=$TESTCASE
export PGSQL_PASSWD=""

# tc combination: 120/60/10/10/0
# workload-warmup time
warmuptime=120
# test-case execution time
export TIME_PER_TC=60
# test-case warmup time
export WARMUP_PER_TC=10
# sleep between 2 scalability
scchangeover=10
# sleep between 2 sub-testcase run (like while switching from rw -> ro)
tcchangeover=0

export SCALE=1250
#export TC_TO_RUN="all ro rw"
export TC_TO_RUN="all"

# x86-vm-server-conf (4 sysbench cores, 8 server cores, 1 numa nodes)
# arm-vm-server-conf (4 sysbench cores, 20 server cores, 1 numa nodes)
export BENCHCORE="0,12,1,13"

# core on target machine
servercore=24

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

export PGSQL_BASE_DIR="/opt/projects/pgsql/non-forked-pgsql/installed"
export PGSQLCMD="$PGSQL_BASE_DIR/bin/psql -d postgres -U $PGSQL_USER"
export PGBENCH="$PGSQL_BASE_DIR/bin/pgbench -U $PGSQL_USER"

if [ ! -f "$PGSQL_BASE_DIR/bin/psql" ]; then
    echo "psql not found. Check/Set 'PGSQL_BASE_DIR'"
    exit 1
fi

if [ ! -f "$PGSQL_BASE_DIR/bin/pgbench" ]; then
    echo "pgbench not found. Check/Set 'PGSQL_BASE_DIR'"
    exit 1
fi

# if there is no pgsql client on local machine then adjust PGSQL_BASE_DIR accordingly.
if [ $SKIPLOAD -eq 0 ]; then
  $PGSQLCMD -c "drop database if exists $PGSQL_DB;" &> /dev/null
  $PGSQLCMD -c "create database $PGSQL_DB;" &> /dev/null
fi

#=======================
# step-2: load data
#=======================

if [ $SKIPLOAD -eq 0 ]; then
  echo -e "\n\n"
  echo "Starting to load tables"
  $PGBENCH -i -s $SCALE $PGSQL_DB 
  $PGSQLCMD -c "checkpoint" &> /dev/null
fi

#=======================
# step-3: warmup <usage: script-name <warm-uptime>
#=======================

if [[ $warmuptime -ne 0 ]]; then
  echo 'Warming up DB'
  $PGBENCH $PGSQL_DB -s $SCALE -T $warmuptime -S -c $servercore -M prepared -P 5 -r &>> output/$TESTCASE/warmup.out
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

#---- all
count=1
if [[ $TC_TO_RUN =~ "all" ]]; then
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

    echo "Running default (select + update (5)) with $count threads"
    $TASKSET $PGBENCH $PGSQL_DB -s $SCALE -T $TIME_PER_TC -c $count -M prepared -P 5 -r &>> output/$TESTCASE/pgbench-all.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping default selection"
fi

echo "Workload processed"
echo -e "\n\n"

#=======================
# step-5
# processing result. <usage: script-name $TESTCASE>
#=======================
echo "Processing result"
./process-result/presult.sh $TESTCASE

$PGSQLCMD -c "checkpoint" 2> /dev/null
