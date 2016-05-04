#!/bin/sh
# Configures the rabbitmq OCF primitive
# wait for the crmd to become ready
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
count=0
while [ $count -lt 160 ]
do
  if timeout --signal=KILL 5 crm_attribute --type crm_config --query --name dc-version | grep -q 'dc-version'
  then
    break
  fi
  count=$((count+10))
  sleep 10
done

# create the required pacemaker primitive for OCF RA under test,
# w/a https://github.com/ClusterLabs/crmsh/issues/120
# retry for the cib patch diff Error 203
count=0
while [ $count -lt 160 ]
do
  crm configure<<EOF
  property stonith-enabled=false
  property no-quorum-policy=stop
  commit
EOF
  crm --force configure primitive p_mysql ocf:mysql:mysql \
        params debug="true" config="/etc/mysql/my.cnf" test_passwd="root" test_user="root" \
        pid="/var/run/mysqld/mysqld.pid" socket="/var/run/mysqld/mysqld.sock" \
        op monitor interval=60 timeout=90 \
        op start interval=0 timeout=60 \
        op stop interval=0 timeout=120 \
        meta migration-threshold=10 failure-timeout=30s resource-stickiness=100 && \
  crm --force configure clone p_mysql-clone p_mysql
  [ $? -eq 0 ] && break
  count=$((count+10))
  sleep 10
done

crm configure location mysql_$HOSTNAME p_mysql-clone 100: $HOSTNAME
exit 0
