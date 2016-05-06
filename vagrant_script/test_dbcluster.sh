#!/bin/bash
# Smoke test for a DB cluster of given # of nodes as $1,
# wait for a given $WAIT env var
# run on remote node $2, if given or on itself.
if [ "$2" ]; then
  cmd="ssh ${2} timeout --signal=KILL 10 mysql -uroot -proot -Nbe \"show global status like 'wsrep%'\""
else
  cmd="timeout --signal=KILL 10 mysql -uroot -proot -Nbe \"show global status like 'wsrep%'\""
fi
count=0
result="FAILED"
throw=1
WAIT="${WAIT:-180}"
while [ $count -lt $WAIT ]
do
  if [ "$2" ]; then
    output=`$cmd 2>/dev/null`
  else
    output=$(bash -c "${cmd}" 2>/dev/null)
  fi
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
  sleep 30
done

echo "DB cluster smoke test: ${result}"
exit $throw
