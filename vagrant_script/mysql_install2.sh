#!/bin/sh
# Install the percona galera 5.6 packages or from a given 5.7 tar path $1
# if requested.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

#Install v5.6
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 1C4CBDCDCD2EFD2A
echo 'deb http://repo.percona.com/apt jessie main' > /etc/apt/sources.list.d/percona.list
echo "Package: *
Pin: origin repo.percona.com
Pin-Priority: 1000" > /etc/apt/preferences.d/00percona.pref

apt-get update
echo "percona-xtradb-cluster-56 mysql-server/root_password password root" | debconf-set-selections
echo "percona-xtradb-cluster-56 mysql-server/root_password_again password root" | debconf-set-selections
echo "percona-xtradb-cluster-56 mysql-server-5.6/start_on_boot boolean false" | debconf-set-selections
echo "percona-xtradb-cluster-server-5.6 percona-xtradb-cluster-server/root_password_again password root" | debconf-set-selections
echo "percona-xtradb-cluster-server-5.6 percona-xtradb-cluster-server/root_password password root" | debconf-set-selections
apt-get -y install percona-xtradb-cluster-server-5.6 socat libev4 libnuma1 libaio1

# Get the most recent Galera replication library 3.16
#apt-get -y install percona-galera-3 || apt-get -y install galera-3
#mkdir -p /usr/lib/galera/
#cd /usr/lib/galera/
#ln -sf /usr/lib/galera3/libgalera_smm.so .
#cd -
wget http://releases.galeracluster.com/debian/pool/main/g/galera-3/galera-3_25.3.16-1jessie_amd64.deb \
-O /tmp/galera-3_25.3.16-1jessie_amd64.deb
dpkg -i --force-all /tmp/galera-3_25.3.16-1jessie_amd64.deb

if [ "$1" ]; then
  #In place upgrade from a given tar for percona
  #TODO(wsrep cannot be loaded)
  echo "percona-server-server-5.6 percona-server-server/root_password password root" | debconf-set-selections
  echo "percona-server-server-5.6 percona-server-server/root_password_again password root" | debconf-set-selections
  echo "percona-server-server-5.6 percona-server-server-5.6/start_on_boot boolean false" | debconf-set-selections
  echo "percona-server-server-5.6 percona-server-server-5.6/postrm_remove_databases boolean true" | debconf-set-selections

  echo "percona-server-server-5.7 percona-server-server-5.7/re-root-pass password root" | debconf-set-selections
  echo "percona-server-server-5.7 percona-server-server-5.7/root-pass password root" | debconf-set-selections
  echo "percona-server-server-5.7 percona-server-server-5.7/data-dir note /var/lib/mysql" | debconf-set-selections
  echo "percona-server-server-5.7 percona-server-server-5.7/remove-data-dir boolean true" | debconf-set-selections
  tar xf "$1" -C /tmp
  dpkg -i --force-all /tmp/libpercona* /tmp/percona*
fi

#upgrade xtrabackup as well
wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.3.4/binary/debian/wily/x86_64/percona-xtrabackup_2.3.4-1.wily_amd64.deb \
-O /tmp/percona-xtrabackup_2.3.4-1.wily_amd64.deb
dpkg -i --force-all /tmp/percona-xtrabackup_2.3.4-1.wily_amd64.deb

if [ "$1" ]; then
  mysqld --initialize --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
else
  mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
fi
service mysql stop
exit $?
