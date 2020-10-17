#!/bin/bash

THDS=$1
TC=$SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_read_only.lua"

./workload/run.sh $THDS $TC
