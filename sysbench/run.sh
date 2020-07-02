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

#export MYSQL_HOST="192.168.0.239"
export MYSQL_HOST="localhost"
export MYSQL_PORT=4000
export MYSQL_SOCK="/tmp/n1.sock"
export MYSQL_USER="root"
export MYSQL_DB=$TESTCASE
export MYSQL_PASSWD=""

export TABLES=100
export TABLE_SIZE=5000000
export TIME_PER_TC=60
export WARMUP_PER_TC=5
export TC_TO_RUN="rw ui uni ro ps"

# x86/arm-vm-conf
export BENCHCORE="0,12,1,13"

# x86-bms-server-conf
#export BENCHCORE="0,18,36,54,1,19,37,55"
# arm-bms-server-conf
#export BENCHCORE="0,32,1,33,2,34,3,35"

# x86-bms-conf
#export BENCHCORE="0,18,36,54,1,19,37,55,2,20,38,56"
# arm-bms-conf
#export BENCHCORE="0,64,32,96,1,65,33,97,2,66,34,98,3,67,35,99"

# sleep between rounds
tcchangeover=0
# sleep between 2 scalability changeover
scchangeover=10
# warmup time
warmuptime=60

# rounds to carry-out
rounds=3

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

SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  SOCK="--socket=$MYSQL_SOCK"
fi

export MYSQL_BASE_DIR=`grep "basedir" conf/n1.cnf | cut -d '=' -f 2`
export MYSQLCMD="$MYSQL_BASE_DIR/bin/mysql -h $MYSQL_HOST -P $MYSQL_PORT $SOCK \
            -u $MYSQL_USER --password=$MYSQL_PASSWD"

# if there is no mysql client on local machine then adjust MYSQL_BASE_DIR accordingly.
if [ $SKIPLOAD -eq 0 ]; then
  $MYSQLCMD -e "drop database if exists $MYSQL_DB; create database $MYSQL_DB" 2> /dev/null
fi

#=======================
# step-2: load data
#=======================

if [ $SKIPLOAD -eq 0 ]; then
  echo -e "\n\n"
  echo "Starting to load $TABLES tables (each with $TABLE_SIZE rows)"
  ./load-data/load-data.sh &> output/$TESTCASE/load-data.out
  $MYSQLCMD -e "purge binary logs before NOW();" 2> /dev/null
  sleep $tcchangeover
fi


#=======================
# step-3
# actual workload. <usage: script-name <threads> <time>>
#=======================
# workload will auto-calculate number of threads to use based on core
# if core = 16 then scalability would be < 16 * 10 (160). So test-case will
# run for 1/2/4/8/16/32/64/128 only.
NCORE=$(( 12*$servercore ))

function execute_tc {
  testname=$1

  # warmup
  ./workload/$testname.sh $servercore &>> output/$TESTCASE/warmup.$testname.out
  sleep $scchangeover

  for (( rnds=1; rnds<=rounds; rnds++ ))
  do
    count=1
    for (( iter=1; count<=NCORE; iter++ ))
    do
      echo "Running $testname with $count threads (Round: $rnds)"
      ./workload/$testname.sh $count &>> output/$TESTCASE/$testname.out
      count=$(( count * 2 ))
      sleep $scchangeover
    done
    $MYSQLCMD -e "purge binary logs before NOW();" 2> /dev/null
  done
  sleep $tcchangeover
}

#---- oltp-point-select
if [[ $TC_TO_RUN =~ "ps" ]]; then
  execute_tc "oltp-point-select"
else
  echo "Skipping oltp-point-select"
fi

#---- oltp-point-select
if [[ $TC_TO_RUN =~ "ro" ]]; then
  execute_tc "oltp-ro"
else
  echo "Skipping oltp-read-only"
fi

#---- oltp-rw
if [[ $TC_TO_RUN =~ "rw" ]]; then
  execute_tc "oltp-rw"
else
  echo "Skipping oltp-read-write"
fi

#---- oltp-point-select
if [[ $TC_TO_RUN =~ "ui" ]]; then
  execute_tc "oltp-update-index"
else
  echo "Skipping oltp-update-index"
fi

#---- oltp-point-select
if [[ $TC_TO_RUN =~ "uni" ]]; then
  execute_tc "oltp-update-non-index"
else
  echo "Skipping oltp-update-non-index"
fi

#=======================
# step-4
# processing result. <usage: script-name $TESTCASE>
#=======================
echo "Processing result"
./process-result/presult.withagregator.sh $TESTCASE $NCORE $rounds true

