#!/bin/sh -e
# Install the percona galera 5.6 packages or from a given 5.7 tar path $1
# if requested.
# Protect from an incident running on hosts which aren't n1, n2, etc.
STORAGE=${STORAGE:-/tmp}
XTRA_VER=${XTRA_VER:-2.3.5-1.jessie}
XTRA=${XTRA_VER%-*}
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

#Install v5.6
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 1C4CBDCDCD2EFD2A 9334A25F8507EFA5
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
apt-get -y --no-install-recommends install percona-xtradb-cluster-server-5.6 percona-xtradb-cluster-common-5.6 percona-xtradb-cluster-client-5.6 mysql-common percona-xtradb-cluster-galera-3

# Get the most recent Galera replication library
#[ -f "${STORAGE}/galera-3_${1}-1jessie_amd64.deb" ] || wget http://releases.galeracluster.com/debian/pool/main/g/galera-3/galera-3_${1}-1jessie_amd64.deb -O /${STORAGE}/galera-3_${1}-1jessie_amd64.deb
#dpkg -i --force-all /${STORAGE}/galera-3_${1}-1jessie_amd64.deb
mkdir -p /usr/lib/galera
ln -s /usr/lib/galera3/libgalera_smm.so /usr/lib/galera/libgalera_smm.so

#upgrade xtrabackup as well
[ -f "${STORAGE}/percona-xtrabackup_${XTRA_VER}_amd64.deb" ] || wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-${XTRA}/binary/debian/jessie/x86_64/percona-xtrabackup_${XTRA_VER}_amd64.deb -O /${STORAGE}/percona-xtrabackup_${XTRA_VER}_amd64.deb
dpkg -i --force-all /${STORAGE}/percona-xtrabackup_${XTRA_VER}_amd64.deb

if [ "$1" ]; then
  mysqld --initialize --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
else
  mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
fi
service mysql stop
sync
