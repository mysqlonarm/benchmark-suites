#!/bin/bash

TC=$1
DIR="output/$TC"
FILES=$DIR/oltp-*.out

for f in $FILES
do
  echo "$f"
  num_of_threads=1
  grep -E -i -w "transactions:|queries:" $f | while read -r line; do
    line1=${line#*(}
    line2=${line1%.*}
    line3=${line2%.*}
    if [[ $line =~ "transactions:" ]]; then
      str1="$num_of_threads # tps: $line3"
    else
      echo "$str1, qps: $line3"
      num_of_threads=$(( 2*$num_of_threads ))
    fi
  done
done

