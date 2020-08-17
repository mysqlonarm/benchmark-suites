#!/bin/bash

for (( c=1; c<=4; c+=1 ))
do
  echo "Running $c iteration"
  ./run2.bms.sh x86 skipload
  mv output/x86 output/x86-v$c
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
  sleep 300
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
done
