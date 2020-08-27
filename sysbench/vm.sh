#!/bin/bash

export DB="arm"
if [[ "`arch`" == "x86_64" ]]; then
  DB="x86"
fi

for (( c=1; c<=4; c+=1 ))
do
  echo "Running $c iteration"
  ./workload.vm.sh $DB skipload
  mv output/$DB output/$DB-v$c
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
  sleep 300
  sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
done
