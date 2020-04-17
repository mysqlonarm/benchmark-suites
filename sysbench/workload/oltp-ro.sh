#!/bin/bash

THDS=$1
TC="/usr/share/sysbench/oltp_read_only.lua"

./workload/run.sh $THDS $TC
