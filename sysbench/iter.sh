#!/bin/bash

for (( c=0; c<=10; c+=1 ))
do
  echo "Running $c iteration"
  ./combi_1.sh arm skipload
  mv output/arm output/arm-v$c
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
  sleep 300 
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
done
