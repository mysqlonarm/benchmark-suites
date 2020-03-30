#!/bin/bash

THDS=$1
TIME=$2
WARMUP_PER_TC=$3
TC="/usr/share/sysbench/oltp_point_select.lua"

./workload/run.sh $THDS $TIME $WARMUP_PER_TC $TC
