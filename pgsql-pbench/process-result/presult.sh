#!/bin/bash

TC=$1
DIR="output/$TC"
FILES=$DIR/pgbench-*.out

for f in $FILES
do
  echo "$f"
  num_of_threads=1
  grep -E -i -w "tps = .*including" $f | while read -r line; do
    line1=${line#*= }
    line2=${line1%.*}
    line3=${line2%.*}
    #tps/qps are same here but still emitting it to maintain output format
    echo "$num_of_threads # tps: $line3, qps: $line3"
    num_of_threads=$(( 2*$num_of_threads ))
  done
done
