#!/bin/bash

THDS=$1
TC="/usr/share/sysbench/oltp_update_non_index.lua"

./workload/run.sh $THDS $TC
