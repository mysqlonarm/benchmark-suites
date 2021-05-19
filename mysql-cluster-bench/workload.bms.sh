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
export MYSQL_MASTER_PORT=4000
export MYSQL_SLAVE1_PORT=5000
export MYSQL_SLAVE2_PORT=6000
export MYSQL_ALLSOCK="/tmp/node1.sock,/tmp/node2.sock,/tmp/node3.sock"
export MYSQL_MASTER_SOCK="/tmp/node1.sock"
export MYSQL_SLAVE1_SOCK="/tmp/node2.sock"
export MYSQL_SLAVE2_SOCK="/tmp/node3.sock"
export MYSQL_USER="root"
export MYSQL_USER="benchuser"
export MYSQL_DB=$TESTCASE
export MYSQL_PASSWD=""
export MYSQL_PASSWD="passwd"

# workload-warmup time
warmuptime=120
# test-case execution time
export time_per_tc=60
# test-case warmup time
export warmup_per_tc=5
# sleep between 2 scalability
export scchangeover=20

export TABLES=30
export TABLE_SIZE=3000000

# the sysbench lua scripts location
export SYSBENCH_LUA_SCRIPT_LOCATION="/usr/share/sysbench"

export allcorebind="numactl --interleave=0 --physcpubind=0-15"
export mastercores="numactl --interleave=0 --physcpubind=0-3"
export slave1cores="numactl --interleave=0 --physcpubind=4-9"
export slave2cores="numactl --interleave=0 --physcpubind=10-15"
clientcorecount=16

# core on target machine
servercore=16

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

MASTER_SOCK=""
SLAVE1_SOCK=""
SLAVE2_SOCK=""
if [[ "$MYSQL_HOST" == "localhost" ]]
then
  MASTER_SOCK="--socket=$MYSQL_MASTER_SOCK"
  SLAVE1_SOCK="--socket=$MYSQL_SLAVE1_SOCK"
  SLAVE2_SOCK="--socket=$MYSQL_SLAVE2_SOCK"
fi

export MYSQL_BASE_DIR=`grep "basedir" cluster-conf/n1.cnf | cut -d '=' -f 2`

if [ ! -f "$MYSQL_BASE_DIR/bin/mysql" ]; then
  echo 'mysql client not found. please consider setting "MYSQL_BASE_DIR"'
  exit 1
fi

export mastercmd="$MYSQL_BASE_DIR/bin/mysql -h $MYSQL_HOST -P $MYSQL_MASTER_PORT $MASTER_SOCK \
            -u $MYSQL_USER --password=$MYSQL_PASSWD"

# if there is no mysql client on local machine then adjust MYSQL_BASE_DIR accordingly.
if [ $SKIPLOAD -eq 0 ]; then
  $mastercmd -e "drop database if exists $MYSQL_DB; create database $MYSQL_DB" 2> /dev/null
fi

slave1cmd="$MYSQL_BASE_DIR/bin/mysql -h $MYSQL_HOST -P $MYSQL_SLAVE1_PORT $SLAVE1_SOCK \
            -u $MYSQL_USER --password=$MYSQL_PASSWD"
slave2cmd="$MYSQL_BASE_DIR/bin/mysql -h $MYSQL_HOST -P $MYSQL_SLAVE2_PORT $SLAVE2_SOCK \
            -u $MYSQL_USER --password=$MYSQL_PASSWD"

#=======================
# step-2: load data
#=======================

if [ $SKIPLOAD -eq 0 ]; then
  echo -e "\n\n"
  echo "starting to load $TABLES tables (each with $TABLE_SIZE rows)"
  ./load-data/load-data.sh $clientcorecount &> output/$TESTCASE/load-data.out
  echo "done with loading. will exit"
  exit 0
fi

#=======================
# step-3: warmup <usage: script-name <warm-uptime>
#=======================

if [[ $warmuptime -ne 0 ]]; then
  echo 'warming up database'
  ./warmup/warmup.sh $clientcorecount $warmuptime &> output/$TESTCASE/warmup.out
  echo -e "done"
fi

#=======================
# step-4
# actual workload. <usage: script-name <threads> <time>>
#=======================
# workload will auto-calculate number of threads to use based on core
# if core = 16 then scalability would be < 16 * 10 (160). So test-case will
# run for 1/2/4/8/16/32/64/128 only.
scaleupto=$(( 12*$servercore ))

# workload
echo "running master-slave workload in background (start monitoring output)"
./workload/master.run.sh $scaleupto $SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_update_index.lua" &> output/$TESTCASE/master.out &
./workload/slave1.run.sh $scaleupto $SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_read_only.lua" &> output/$TESTCASE/slave1.out &
./workload/slave2.run.sh $scaleupto $SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_read_only.lua" &> output/$TESTCASE/slave2.out &

sleepcounter=0;
for (( c=1; c<=$scaleupto; c*=2 ))
do
    ((sleepcounter++))
done
sleepcounter=$((sleepcounter*(time_per_tc+scchangeover)*3/2))

./workload/sbm.monitor.sh "$mastercmd" $sleepcounter &> output/$TESTCASE/master.sbm.out &
./workload/sbm.monitor.sh "$slave1cmd" $sleepcounter &> output/$TESTCASE/slave1.sbm.out &
./workload/sbm.monitor.sh "$slave2cmd" $sleepcounter &> output/$TESTCASE/slave2.sbm.out &

for (( c=1; c<=$sleepcounter; c+=1 ))
do
  echo -n "."
  sleep 1
done

echo "should be done by now"


