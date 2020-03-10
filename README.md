# benchmark-suites
Benchmark Suite Invocation Scripting

<b>sysbench:</b>

sysbench has multiple test-cases and has mutliple configurations to pass. To help ease this aspect sysbench suite helps automate the invocation.

User should only edit combi_1.sh and review the setting at the top of the file to ensure it is inline with their enviornment (like mysql_host, mysql_user, mysql_password, mysql_port, number of table, table-size, etc....).

[TC_TO_RUN helps user select which sub-test-cases to run like read-write/read-only/point-select/update-index/update-non-index].

<b>Avoid editting anything beyond the initial environment variable settings.</b>

User should also look at the provided conf/n1.cnf for reference purpose and tune local my.cnf accordingly.

Invocation is simple as ./combi_1 <tc-name>

<i>for example: ./combi_1 cacheline128<i>

This will create a folder name output/cacheline128 that will have logs of the sub-command invoked.
Above command will also print a summary at the end of the test.


