#!/bin/bash

THDS=$1
TIME=$2
WARMUP_PER_TC=$3
TC="/usr/share/sysbench/oltp_update_non_index.lua"

./workload/run.sh $THDS $TIME $WARMUP_PER_TC $TC
