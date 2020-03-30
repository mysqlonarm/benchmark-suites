#!/bin/bash

THDS=$1
TIME=$2
WARMUP_PER_TC=$3
TC="/usr/share/sysbench/oltp_read_only.lua"

./workload/run.sh $THDS $TIME $WARMUP_PER_TC $TC
