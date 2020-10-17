#!/bin/bash

THDS=$1
TC=$SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_update_non_index.lua"

./workload/run.sh $THDS $TC
