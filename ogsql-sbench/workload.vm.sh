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
export GSQL_PASSWD="RootPass123"

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

export TABLES=50
export TABLE_SIZE=1500000
export TC_TO_RUN="rw upd upd-ni ro ps"

# the sysbench lua scripts location
export SYSBENCH_LUA_SCRIPT_LOCATION="/usr/share/sysbench"

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

export GSQL_BASE_DIR="/opt/projects/ogauss/non-forked-ogauss/installed"
export GSQLCMD="$GSQL_BASE_DIR/bin/gsql -d postgres -U $GSQL_USER -W $GSQL_PASSWD"

if [ ! -f "$GSQL_BASE_DIR/bin/gsql" ]; then
    echo "gsql not found. Check/Set 'GSQL_BASE_DIR'"
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
  echo "Starting to load $TABLES tables (each with $TABLE_SIZE rows)"
  ./load-data/load-data.sh &> output/$TESTCASE/load-data.out
  $GSQLCMD -c "checkpoint" 2> /dev/null
  sleep $tcchangeover
fi

#=======================
# step-3: warmup <usage: script-name <warm-uptime>
#=======================

if [[ $warmuptime -ne 0 ]]; then
  echo 'Warming up DB'
  ./warmup/warmup.sh $servercore $warmuptime &> output/$TESTCASE/warmup.out
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

#---- oltp-point-select
count=1
if [[ $TC_TO_RUN =~ "ps" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-point-select with $count threads"
    ./workload/oltp-point-select.sh $count &>> output/$TESTCASE/oltp-point-select.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-point-select"
fi

#---- oltp-ro
count=1
if [[ $TC_TO_RUN =~ "ro" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-read-only with $count threads"
    ./workload/oltp-ro.sh $count &>> output/$TESTCASE/oltp-ro.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-ro"
fi

#---- oltp-rw
count=1
if [[ $TC_TO_RUN =~ "rw" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-rw with $count threads"
    ./workload/oltp-rw.sh $count &>> output/$TESTCASE/oltp-rw.out
    count=$(( count * 2 ))
    sleep $scchangeover
  done
  sleep $tcchangeover
else
  echo "Skipping oltp-rw"
fi

#---- oltp-update-index
count=1
if [[ $TC_TO_RUN =~ "upd" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-update-index with $count threads"
    ./workload/oltp-update-index.sh $count &>> output/$TESTCASE/oltp-update-index.out
    count=$(( count * 2 ))
    sleep $scchangeover
  done
  sleep $tcchangeover
else
  echo "Skipping oltp-update-index"
fi

#---- oltp-update-non-index
count=1
if [[ $TC_TO_RUN =~ "upd-ni" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-update-non-index with $count threads"
    ./workload/oltp-update-non-index.sh $count &>> output/$TESTCASE/oltp-update-non-index.out
    count=$(( count * 2 ))
    sleep $scchangeover
  done
  sleep $tcchangeover
else
  echo "Skipping oltp-update-non-index"
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
