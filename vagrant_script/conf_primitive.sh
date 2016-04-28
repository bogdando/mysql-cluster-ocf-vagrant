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
# remove old node's names artifact
# w/a https://github.com/ClusterLabs/crmsh/issues/120
# retry for the cib patch diff Error 203
crm configure show p_mysql && exit 0
count=0
while [ $count -lt 160 ]
do
  crm configure<<EOF
  property stonith-enabled=false
  property no-quorum-policy=stop
  commit
EOF
  (echo y | crm configure primitive p_mysql ocf:mysql:mysql \
        params debug="true" config="/etc/mysql/my.cnf" test_passwd="root" test_user="root" \
        pid="/var/run/mysqld/mysqld.pid" socket="/var/run/mysqld/mysqld.sock" \
        op monitor interval=60 timeout=90 \
        op start interval=0 timeout=60 \
        op stop interval=0 timeout=120 \
        meta migration-threshold=10 failure-timeout=30s resource-stickiness=100) && \
  (echo y | crm configure clone p_mysql-clone p_mysql)
  [ $? -eq 0 ] && break
  count=$((count+10))
  sleep 10
done
(echo n | crm configure location foo p_mysql-clone inf: n1)

# Prepare for debug logs
dir=/tmp/mysql.ocf.ra.debug
mkdir -p $dir
touch ${dir}/log
chmod 700 ${dir}/log

exit 0
