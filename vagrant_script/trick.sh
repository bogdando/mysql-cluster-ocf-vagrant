#!/bin/sh                                                                                                                                                                                 
# A dirty trick to bootsrap a galera cluster starting from the node n1
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
count=0

# Apply only for the node n1
hostname | grep -q "^n1"
[ $? -eq 0 ] || exit 0

while [ $count -lt 160 ]
do
  if timeout --signal=KILL 5 crm_attribute --type crm_config --query --name dc-version | grep -q 'dc-version'
  then
    break
  fi
  count=$((count+10))
  sleep 10
done

mkdir -p /var/lib/mysql/
crm_attribute --quiet --node n1 --lifetime reboot --name gtid --update 00000000-0000-0000-0000-000000000000:0
echo "uuid 00000000-0000-0000-0000-000000000000:0" > /var/lib/mysql/grastate.dat
chown mysql.mysql /var/lib/mysql/grastate.dat
echo y | crm configure location foo p_mysql-clone inf: n1
