#!/bin/bash

g++ -O2 -g loadstore.cc -lpthread -lz -o loadstore
g++ -O2 -g loadstore.cc -DOPTIMIZED -lpthread -lz -o loadstore-opt

for (( c=1; c<=256; c*=2 ))
do
  echo "Running $c parallelism"
  ./loadstore $c
  ./loadstore-opt $c
done;
