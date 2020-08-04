#!/bin/bash

for (( c=1; c<=4; c+=1 ))
do
  echo "Running $c iteration"
  ./run2.bms.sh arm skipload
  mv output/arm output/arm-v$c
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
  sleep 30
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
done
