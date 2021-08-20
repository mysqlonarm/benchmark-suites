#!/bin/bash

g++ -O2 -g loadstore.cc -lpthread -o loadstore
g++ -O2 -g loadstore.cc -DOPTIMIZED -lpthread -o loadstore-opt

for (( c=1; c<=256; c*=2 ))
do
  echo "Running $c parallelism"
  ./loadstore $c
  echo 3 > /proc/sys/vm/drop_caches
  ./loadstore-opt $c
done;
