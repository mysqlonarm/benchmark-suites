#! /bin/bash
cd global-counters/pthreadmutex && rm -rf pthreadmutex && ./compile.sh && ./run.sh &> ../../output/run1.out && cd ../../
cd global-counters/stdmutex && rm -rf stdmutex &&  ./compile.sh && ./run.sh &> ../../output/run2.out && cd ../../
cd global-counters/atomic && rm -rf atomic &&  ./compile.sh && ./run.sh &> ../../output/run3.out && cd ../../
cd global-counters/fuzzycounter && rm -rf fuzzycounter && ./compile.sh && ./run.sh &> ../../output/run4.out && cd ../../
cd global-counters/shardatomiccounter && rm -rf shardatomiccounter && ./compile.sh && ./run.sh &> ../../output/run5.out && cd ../../
cd global-counters/shardatomiccounter-tid && rm -rf shardatomiccounter-tid && ./compile.sh && ./run.sh &> ../../output/run6.out && cd ../../
cd global-counters/shardatomiccounter-cpuid && rm -rf shardatomiccounter-cpuid && ./compile.sh && ./run.sh &> ../../output/run7.out && cd ../../
cd global-counters/shardatomiccounter-numaid && rm -rf shardatomiccounter-numaid && ./compile.sh && ./run.sh &> ../../output/run8.out && cd ../../
