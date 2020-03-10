# benchmark-suites
Benchmark Suite Invocation Scripting

<b>sysbench:</b>

sysbench has multiple test-cases and has mutliple configurations to pass. To help ease this aspect sysbench suite helps helps automate the invocation.

User should only edit combi_1.sh that review the setting at the top of the file to ensure it is inline with their enviornment.
Avoid editting anything beyond the initial environment variable settings.

User should also look at the provided conf/n1.cnf for reference purpose and tune local my.cnf accordingly.

Invocation is simple as ./combi_1 <tc-name>

<i>for example: ./combi_1 cacheline128<i>
