#!/bin/bash
# Configure mysql galera cluster bootstrap.
# Based on https://github.com/kubernetes/kubernetes/blob/master/examples/mysql-galera/image/docker-entrypoint.sh
# env: WSREP_CLUSTER_ADDRESS, "gcomm://" for the main node other join to, or empty
# args $1 =  number of nodes, like 5 => n1 n2 n3 n4 n5
# $2 = SST wsrep method, or autoselect
NAME=$(hostname)
CONF_FILE=/etc/mysql/my.cnf
# SST method, default xtrabackup-v2, fallback to mysqldump
if [ "$2" ]; then
  WSREP_SST=$2
else
  if test -f /usr/bin/wsrep_sst_xtrabackup-v2
  then
    WSREP_SST=xtrabackup-v2
  else
    WSREP_SST=mysqldump
  fi
fi

# set nodes own address
WSREP_NODE_ADDRESS=`ip addr show | grep -E '^[ ]*inet' | grep -m1 global | awk '{ print $2 }' | sed -e 's/\/.*//'`
if [ -n "$WSREP_NODE_ADDRESS" ]; then
  sed -i -e "s|^#wsrep_node_address =.*$|wsrep_node_address = ${WSREP_NODE_ADDRESS}|" $CONF_FILE
fi

# if the string is not defined or it only is 'gcomm://', this means bootstrap
if [ -z "$WSREP_CLUSTER_ADDRESS" -o "$WSREP_CLUSTER_ADDRESS" = "gcomm://" ]; then
  # if empty, set to 'gcomm://'
  # NOTE: this list does not imply membership.
  # It only means "obtain SST and join from one of these..."
  if [ -z "$WSREP_CLUSTER_ADDRESS" ]; then
    WSREP_CLUSTER_ADDRESS="gcomm://"
  fi

  # loop through number of nodes
  for NUM in `seq 1 $1`; do
    NODE_SERVICE_HOST="n${NUM}"

    # if not its own IP, then add it
    if [ $(expr "$name" : "n${NUM}") -eq 0 ]; then
      # if not the first bootstrap node add comma
      if [ $WSREP_CLUSTER_ADDRESS != "gcomm://" ]; then
        WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS},"
      fi
      # append
      WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS}n${NUM}"
    fi
  done
fi

# WSREP_CLUSTER_ADDRESS is now complete and will be interpolated into the
# cluster address string (wsrep_cluster_address) in the cluster
# configuration file, cluster.cnf
if [ -n "$WSREP_CLUSTER_ADDRESS" -a "$WSREP_CLUSTER_ADDRESS" != "gcomm://" ]; then
  sed -i -e "s|^#wsrep_cluster_address = .*$|wsrep_cluster_address = ${WSREP_CLUSTER_ADDRESS}|" $CONF_FILE
fi

seed=$(hostname -I | sed -e 's/ /\n/' | grep -v '^$'  | tail -1 | awk -F. '{print $3 * 256 + $4}')
sed -i -e "s/^#server\-id =.*$/server-id = ${seed}/" $CONF_FILE

# settings for SST, prov opts and binding
sed -i -e "s/^#bind-address =.*$/bind-address = $WSREP_NODE_ADDRESS/" $CONF_FILE
sed -i -e "s/^#wsrep_node_incoming_address =.*$/wsrep_node_incoming_address = $WSREP_NODE_ADDRESS/" $CONF_FILE
sed -i -e "s|^#wsrep_provider_options =.*$|wsrep_provider_options = \"gcache.size=256M; gmcast.listen_addr=tcp://$WSREP_NODE_ADDRESS:4567\"|" $CONF_FILE
sed -i -e "s/^#wsrep_sst_receive_address =.*$/wsrep_sst_receive_address = $WSREP_NODE_ADDRESS/" $CONF_FILE
sed -i -e "s/^#wsrep_sst_method =.*$/wsrep_sst_method = $WSREP_SST/" $CONF_FILE
