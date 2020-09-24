# benchmark-suites

Benchmark Suite Invocation Scripting

**sysbench:**

sysbench has multiple test-cases and has mutliple configurations to pass. To help ease this aspect sysbench suite helps automate the invocation.

User should only edit `workload.vm.sh` or `workload.bms.sh` and review the setting at the top of the files to ensure it is inline with their enviornment (like mysql_host, mysql_user, mysql_password, mysql_port, number of table, table-size, etc....).

The parameter `TC_TO_RUN` helps user select which sub-test-cases to run like read-write/read-only/point-select/update-index/update-non-index.

>Note: Avoid editting anything beyond the initial environment variable settings.

User should also look at the provided `conf/n1.cnf` for reference purpose and tune local my.cnf accordingly.

Invocation is simple as `./workload.vm.sh <tc-name>`

for example:

```shell
./workload.vm.sh cacheline128 [skipload]
```

This will create a folder name output/cacheline128 that will have logs of the sub-command invoked.

Above command will also print a summary at the end of the test.

[skipload]: optional parameter that will skip create/load of the database.
Normal sequence executes following steps: load, warmup, workload, summary.

load will load the database from scratch. If user would like to re-use the same database then simply use skipload.

>Note: name of the database is same as name of the test-case. Like in case above it would cacheline128 database so if you use skipload then backup existing test-case folder and re-run with same test-case name as db with same name should exist.
