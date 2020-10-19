#!/bin/bash

export DB="arm"
if [[ "`arch`" == "x86_64" ]]; then
  DB="x86"
fi

for (( c=1; c<=4; c+=1 ))
do
  echo "Running $c iteration"
  ./workload.bms.sh $DB skipload
  mv output/$DB output/$DB-v$c
done
