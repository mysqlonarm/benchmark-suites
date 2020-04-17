#!/bin/bash

THDS=$1
TC="/usr/share/sysbench/oltp_point_select.lua"

./workload/run.sh $THDS $TC
