#!/bin/bash

sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
./atomic 256 100 1000000 10000 numa
sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
numactl --interleave=all ./atomic 256 100 1000000 10000
