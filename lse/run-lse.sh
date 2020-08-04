#!/bin/bash

g++ -O2 -g lse.cc -lpthread -lz -o lse -march=armv8-a+lse
#g++ -O2 -g lse.cc -lpthread -lz -o lse

for (( c=1; c<=2048; c*=2 ))
do
  echo "Running $c parallelism"
  ./lse $c
done;
