#!/bin/bash

THDS=$1
TIME=$2
TC="/usr/share/sysbench/oltp_point_select.lua"

./workload/run.sh $THDS $TIME $TC
