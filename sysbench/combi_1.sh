#! /bin/bash

#set -x

if [[ $# -ne 1 ]] ; then
    echo 'usage: combi_1 <test-case-name>'
    exit 1
fi

TESTCASE=$1

export MYSQL_HOST="192.168.1.73"
export MYSQL_PORT=4000
export MYSQL_USER="root"
export MYSQL_DB=$TESTCASE
export MYSQL_PASSWD=""

export TABLES=10
export TABLE_SIZE=10000000
export TIME_PER_TC=60
export TC_TO_RUN="rw upd upd-ni ro ps"

# sleep between 2 sub-testcase run (like while switching from rw -> ro)
changeover=60
# warmup time
warmuptime=120

if [ -d "output/$TESTCASE" ]; then
  echo 'previous run for same test-case is present. please remove it and restart'
  exit 1
fi

#-------------------------------------------------------------------------------------
# execution start. avoid modifying anything post this point. All your enviornment
# variable should be set above.

#=======================
# step-1
#=======================

# if there is no mysql client on local machine then adjust MYSQL_BASE_DIR accordingly.
export MYSQL_BASE_DIR=`grep "basedir" conf/n1.cnf | cut -d '=' -f 2`
$MYSQL_BASE_DIR/bin/mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER \
                          --password=$MYSQL_PASSWD -e "drop database if exists $MYSQL_DB; create database $MYSQL_DB" 2> /dev/null 
rm -rf output/$TESTCASE
mkdir -p output/$TESTCASE


#=======================
# step-2: load data
#=======================

echo -e "\n\n"
echo "Starting to load $TABLES tables (each with $TABLE_SIZE rows)"
./load-data/load-data.sh &> output/$TESTCASE/load-data.out

#=======================
# step-3: warmup <usage: script-name <warm-uptime>
#=======================

echo 'Warming up DB'
./warmup/warmup.sh $warmuptime &> output/$TESTCASE/warmup.out
echo -e "\n\n"


#=======================
# step-4
# actual workload. <usage: script-name <threads> <time>>
#=======================
# workload will auto-calculate number of threads to use based on core
# if core = 16 then scalability would be < 16 * 10 (160). So test-case will
# run for 1/2/4/8/16/32/64/128 only.
NCORE=$(( 10*`nproc` ))

#---- oltp-rw
sleep $changeover
count=1
if [[ $TC_TO_RUN =~ "rw" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-rw with $count threads"
    ./workload/oltp-rw.sh $count $TIME_PER_TC &>> output/$TESTCASE/oltp-rw.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-rw"
fi

#---- oltp-update-index
sleep $changeover
count=1
if [[ $TC_TO_RUN =~ "upd" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-update-index with $count threads"
    ./workload/oltp-update-index.sh $count $TIME_PER_TC &>> output/$TESTCASE/oltp-update-index.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-update-index"
fi

#---- oltp-update-non-index
sleep $changeover
count=1
if [[ $TC_TO_RUN =~ "upd-ni" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-update-non-index with $count threads"
    ./workload/oltp-update-non-index.sh $count $TIME_PER_TC &>> output/$TESTCASE/oltp-update-non-index.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-update-non-index"
fi

#---- oltp-ro
sleep $changeover
count=1
if [[ $TC_TO_RUN =~ "ro" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-read-only with $count threads"
    ./workload/oltp-ro.sh $count $TIME_PER_TC &>> output/$TESTCASE/oltp-ro.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-rw"
fi

#---- oltp-point-select
sleep $changeover
count=1
if [[ $TC_TO_RUN =~ "ps" ]]; then
  for (( iter=1; count<=NCORE; iter++ ))
  do
    echo "Running oltp-point-select with $count threads"
    ./workload/oltp-point-select.sh $count $TIME_PER_TC &>> output/$TESTCASE/oltp-point-select.out
    count=$(( count * 2 ))
  done
else
  echo "Skipping oltp-point-select"
fi

echo "Workload processed"
echo -e "\n\n"


#=======================
# step-5
# processing result. <usage: script-name $TESTCASE> 
#=======================
echo "Processing result"
./process-result/presult.sh $TESTCASE
