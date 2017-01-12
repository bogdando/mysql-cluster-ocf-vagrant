# galera-cluster-ocf-vagrant

[Packer Build Scripts](https://github.com/bogdando/packer-atlas-example)
| [Docker Image (Ubuntu 15.10)](https://hub.docker.com/r/bogdando/pacemaker-cluster-ocf-wily/)
| [Docker Image (Ubuntu 16.04)](https://hub.docker.com/r/bogdando/pacemaker-cluster-ocf-xenial/)

A Vagrantfile to bootstrap a Pacemaker cluster and install a Galera cluster via
[OCF RA](http://www.linux-ha.org/wiki/OCF_Resource_Agents) resource under test.
This uses a Galera packages and a custom
[OCF script](https://github.com/openstack/fuel-library/blob/master/files/fuel-ha-utils/ocf/mysql-wss) from the Fuel for OpenStack.

## Vagrantfile

Supports only docker (experimental) provider.
Requires Docker >=v1.10 and vagrant-triggers plugin for a Vagrant.
TODO(bogdando): add support for debian/centos/rhel images as well.

* Spins up two VM nodes ``[n1, n2, n3]`` with predefined IP addressess
  ``10.10.10.2-4/24`` by default. Use the ``SLAVES_COUNT`` env var, if you need
  more nodes to form a cluster. Note, that the ``vagrant destroy`` shall accept
  the same number as well!
* Creates a corosync cluster with disabled quorum and STONITH.
* Installs MySQL and either Codership, or Percona Galera or MariaDB packages.
* Launches the given MySQL OCF RA under test, which creates the DB cluster.

Note, that constants from the ``Vagrantfile`` may be as well configred as
``vagrant-settings.yaml_defaults`` or ``vagrant-settings.yaml`` and will be
overriden by environment variables, if specified.

Also note, that for workarounds implemented for the docker provider made
the command ``vagrant ssh`` not working. Instead use the
``docker exec -it n1 bash`` or suchlike.

The script `./vagrant_script/mysql_install.sh` installs Codership packages.
The `./vagrant_script/mysql_install2.sh` installs Percona packages. And
`./vagrant_script/mysql_install3.sh` installs MariaDB packages. To switch
across those, update the Vagrant settings file, for example:

* To install MariaDB Galera v10 (from a Debian Jessie mirror) put the
  `galera_distro: mariadb`. It uses xtrabackup-v2 sst method (see ``*xtra*``
  vars for the tool versions.
* To install Codership Galera, put the `galera_distro: codership`. It works
  only with ``wsrep_sst_method: mysqldump``.
* To install latest Percona v5.6 from Jessie mirrors, put the
  `galera_distro: percona`. It uses xtrabackup-v2 sst as well.

## Caching

Use `docker_mounts` to specify pre-downloaded package, f.e.:
```
wget http://releases.galeracluster.com/debian/pool/main/g/galera-3/galera-3_25.3.19-1jessie_amd64.deb \
-O /var/tmp/galera-3_25.3.19-1jessie_amd64.deb
wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.3.5/binary/debian/wily/x86_64/percona-xtrabackup_2.3.5-1.wily_amd64.deb
-O /var/tmp/percona-xtrabackup_2.3.5-1.wily_amd64.deb
export DOCKER_MOUNTS="/var/tmp:/var/tmp:ro jepsen:/jepsen:ro /tmp/sshkey:/root/.ssh/id_rsa:ro"
export STORAGE="/var/tmp"
```

## Known issues

* A Pacemaker may behave strange in VM-like containers: ``crm_node -l`` may start
  reporting empty nodes lists or pacemakerd may die for a some strange reason.
  That was seen when using custom docker run commands, which are not ``/sbin/init``.

* For the docker provider, a networking is [not implemented](https://github.com/mitchellh/vagrant/issues/6667)
  and there is no [docker-exec privisioner](https://github.com/mitchellh/vagrant/issues/4179)
  to replace the ssh-based one. So I put ugly workarounds all around to make
  things working more or less.

* If ``vagrant destroy`` fails to teardown things, just repeat it few times more.
  Or use ``docker rm -f -v`` to force manual removal, but keep in mind that
  that will likely make your docker images directory eating more and more free
  space.

* Make sure there is no conflicting host networks exist, like
  ``packer-atlas-example0`` or ``vagrant-libvirt`` or the like. Otherwise nodes may
  become isolated from the host system.

* For Ubuntu host OS, mysql does not work with privileged containers due to [apparmor
  issues](https://github.com/docker/docker/issues/5490). And w/o priv mode, there
  are strange things may happen to the VM like containers running /sbin/init as
  the entrypoint, so take care (and re-try vagrant down/up).

* A jepsen test may hang like if is waiting for something and leave blocking iptables
  rules after Nemesis undone. Just kill the test and remove the rules, for
  example ``for i in 1 2 3 4 5; do docker exec -it n$i bash -c "iptables -F -w ;
  iptables -X -w"; done``

* If the terminal session looks "broken" after the ``vagrant up/down``, issue a
  ``reset`` command as well.

## Troubleshooting

You may want to use the command like:
```
VAGRANT_LOG=info SLAVES_COUNT=2 vagrant up 2>&1| tee out
```

There was added "Crafted:", "Executing:" log entries for the
provision shell scripts.

For the MySQL OCF RA you may use the command like:
```
`(OCF_RESKEY_additional_parameters="--wsrep-new-cluster")` OCF_RESOURCE_INSTANCE=p_mysql \
OCF_ROOT=/usr/lib/ocf OCF_RESKEY_test_passwd=root OCF_RESKEY_test_user=root \
OCF_RESKEY_pid=/var/run/mysqld/mysqld.pid OCF_RESKEY_socket=/var/run/mysqld/mysqld.sock \
OCF_RESKEY_debug=true /usr/lib/ocf/resource.d/mysql/mysql monitor
```

The optional part in the brackets will tell the RA to bootsrap a new cluster instead
of trying to join the existing one. Debug (bash -xx) logs may be found in
`/tmp/mysql.ocf.ra.debug/log`.

It puts its logs under ``/var/log/syslog`` from the `ocf-mysql-wss` program tag.

## Jepsen tests

[Jepsen](https://github.com/aphyr/jepsen) is good to find out how resilient,
consistent, available your distributed system is. For OCF RA acting as
clusterers, it may be nice to know if the cluster recovers from network
partitions well. And history validation comes just as a free bonus :-)
Although the jepsen test results may be ignored because it maybe rather
related to the cluster/distributed system itself than to the OCF RA clusterer
or a Pacemaker.

The idea is to bootstrap Pacemaker cluster with a cluster assembpled by the
OCF RA under test, and allow Jepsen to continuousely do hammering of the cluster
with Nemesis strikes. Then check if the cluster has been recovered. And of cause
you may want to look into the
[history validation](https://aphyr.com/posts/314-computational-techniques-in-knossos)
results as well. Hopefully, that would give you insights on the cluster
(or a Pacemaker) configuration settings!

Also note that both smoke and jepsen tests will perform an *integration testing*
of the complete setup, which is Corosync/Pacemaker cluster plus the subject
cluster on top. Keep in mind that network partitions may kill the Pacemaker
cluster as well.

To proceed with jepsen tests, firstly create an ssh key with:
```
cat /dev/random | ssh-keygen -b 1024 -t rsa -f /tmp/sshkey -q -N ""
```
Secondly, update `./conf` files as required for a test case and define the env
settings variables in the `./vagrant-settings.yaml_defaults` file. For example,
let's use `jepsen_app: rabbit_ocf_pcmk`, `rabbit_ver: 3.5.7`.

Then set `use_jepsen: "true"` in the env settings  and run ``vagrant up``.
It launches a control node n0 and five nodes named n1, n2, n3, n4, n5. Jepsen logs
and results may be found in the shared volume named `jepsen`, in the `/logs`.

NOTE: The `jepsen` volume contains a shared state, like the lein docker image and
the jepsen repo/jarfile/results, for consequent vagrant up/destroy runs. If
something went wrong, you can safely delete it. Then it will be recreated from the
scratch as well.

To collect logs at the host OS under the `/tmp/results.tar.gz`, use the command like:
```
docker run -it --rm -e "GZIP=-9" --entrypoint /bin/tar -v jepsen:/results:ro -v
/tmp:/out ubuntu cvzf /out/results.tar.gz /results/logs
```

To run lein commmands, use ``docker exec -it jepsen lein foo`` from the control node.
For example, to test a multi master writes/reads mode, it may be:
```
lein test :only jepsen.percona_ocf_pcmk-test/bank-test-multi
```
or just ``lein test`` to run all of the test cases, or even something like
```
PURGE=true bash -xx /vagrant/vagrant_script/lein_test.sh percona_ocf_pcmk bank-test-single
```
Note, that `PURGE` will stop & remove the jepsen container, if running. You may
want to do this, if things become strange. Although be prepared for a long
container start up as it'd install the gnuplot (required by Jepsen) with many dependencies.
