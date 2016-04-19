#!/bin/bash
# Smoke test for a DB cluster of given # of nodes as $1,
# wait for a given $WAIT env var
# run on remote node, if the $AT_NODE specified.
# When run localy, provide crm_mon outputs as well.
cmd="timeout --signal=KILL 10 mysql -uroot -proot -e \"show global status like 'wsrep%'\""
[ "${AT_NODE}" ] && cmd="ssh ${AT_NODE} ${cmd}"

count=0
result="FAILED"
throw=1
WAIT="${WAIT:-180}"
while [ $count -lt $WAIT ]
do
  output=`${cmd} 2>/dev/null`
  rc=$?
  state=0

  echo "${output}" | grep -q "wsrep_cluster_size.*$1"
  [ $? -eq 0 ] || state=1
  echo "${output}" | grep -q "wsrep_local_state_comment.*Synced"
  [ $? -eq 0 ] || state=1
  echo "${output}" | grep -q "wsrep_cluster_status.*Primary"
  [ $? -eq 0 ] || state=1
  echo "${output}" | grep -q "wsrep_connected.*ON"                                                                                                                              
  [ $? -eq 0 ] || state=1
  echo "${output}" | grep -q "wsrep_ready.*ON"                                                                                                                              
  [ $? -eq 0 ] || state=1

  if [ $rc -eq 0 -a $state -eq 0 ]; then
    result="PASSED"
    throw=0
    break
  fi
  echo "DB cluster is yet to be ready"
  count=$((count+10))
  if [ -z "${AT_NODE}" ]; then
    echo "Crm_mon says:"
    timeout --signal=KILL 5 crm_mon -fotAW -1
  fi
  sleep 30
done

echo "DB cluster smoke test: ${result}"
exit $throw
