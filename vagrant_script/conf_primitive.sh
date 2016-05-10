#!/bin/sh
# Configures the rabbitmq OCF primitive for a given SST method ($1)
# wait for the crmd to become ready, wait for a given $SEED node.
# Protect from an incident running on hosts which aren't n1, n2, etc.
sst_method=${1:-xtrabackup-v2}
name=$(hostname)
echo $name | grep -q "^n[0-9]\+"
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

# for a seed node, create the required pacemaker primitive for OCF RA under test,
# w/a https://github.com/ClusterLabs/crmsh/issues/120
# retry for the cib patch diff Error 203
if [ "${name}" = "${SEED}" ] ; then
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
          wsrep_sst_method="${sst_method}" \
          pid="/var/run/mysqld/mysqld.pid" socket="/var/run/mysqld/mysqld.sock" \
          op monitor interval=60 timeout=90 \
          op start interval=0 timeout=330 \
          op stop interval=0 timeout=120 \
          meta migration-threshold=10 failure-timeout=30s resource-stickiness=100 && \
    crm --force configure clone p_mysql-clone p_mysql
    [ $? -eq 0 ] && break
    count=$((count+10))
    sleep 10
  done
else
  # wait for a seed node
  while :; do
    crm_resource --locate --resource p_mysql-clone | grep -q "running on.*${SEED}" && break
    echo "Waiting for a seed node ${SEED}"
    sleep 10
  done
fi

crm configure location mysql_$name p_mysql-clone 100: $name
crm resource cleanup p_mysql-clone
exit 0
