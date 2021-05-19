#! /bin/bash

slavecmd=$1
monitorcounter=$2

for (( c=1; c<=$monitorcounter; c+=1 ))
do
 $slavecmd -e "show slave status\G" | grep Seconds_Behind_Maste
 $slavecmd -e "show status like 'wsrep_flow_control_paused_ns'" | grep wsrep_flow_control_paused_ns
 sleep 1
done
