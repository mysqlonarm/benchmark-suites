#!/bin/bash

TC=$1
DIR="output/$TC"
FILES=$DIR/oltp-*.out
NCORE=$2
ROUNDS=$3
ignore_first_iter=$4

if [ $ROUNDS -eq 1 ]; then
  ignore_first_iter=false
elif [ "$ignore_first_iter" = "true" ]; then
  # since the first round will be ignored
  # reduced number of elemented appended
  ROUNDS=`expr $ROUNDS - 1`
fi

declare -a tps
declare -a qps

for f in $FILES
do
  echo "$f"
  num_of_threads=1
  tps_total=0
  qps_total=0
  #grep -E -i -w "transactions:|queries:" $f | while read -r line; do
  while read -r line; do
    line1=${line#*(}
    line2=${line1%.*}
    line3=${line2%.*}
    if [[ $line =~ "transactions:" ]]; then
      if [[ "$ignore_first_iter" = false ]]; then
        #str1="$num_of_threads # tps: $line3"
        tps[$num_of_threads]=`expr ${tps[$num_of_threads]} + $line3`
      fi
    else
      if [[ "$ignore_first_iter" = false ]]; then
        #echo "$str1, qps: $line3"
        qps[$num_of_threads]=`expr ${qps[$num_of_threads]} + $line3`
      fi
      num_of_threads=$(( 2*$num_of_threads ))
    fi

    if [[ $num_of_threads -gt $NCORE ]]; then
      num_of_threads=1
      ignore_first_iter=false
    fi
  done < <(grep -E -i -w "transactions:|queries:" $f)

  for (( idx=1; idx<=$NCORE; idx*=2 ))
  do
  echo "$idx#: tps: `expr ${tps[$idx]} / $ROUNDS` qps: `expr ${qps[$idx]} / $ROUNDS`"
  done

  tps=()
  qps=()

done
