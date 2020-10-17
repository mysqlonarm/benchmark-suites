#!/bin/bash

THDS=$1
TC=$SYSBENCH_LUA_SCRIPT_LOCATION"/oltp_point_select.lua"

./workload/run.sh $THDS $TC
