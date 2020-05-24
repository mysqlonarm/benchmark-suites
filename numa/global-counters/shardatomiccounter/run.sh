#!/bin/bash

sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
./shardatomiccounter 256 100 1000000 10000 numa
sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
numactl --interleave=all ./shardatomiccounter 256 100 1000000 10000
