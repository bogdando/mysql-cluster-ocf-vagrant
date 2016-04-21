#!/bin/sh
# Install the percona galera 5.6 packages
# if requested.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

echo "Package: *
deb http://repo.percona.com/apt jessie main
keys.gnupg.net
1C4CBDCDCD2EFD2A" > /etc/apt/preferences.d/00percona.pref

apt-get update
echo "percona-xtradb-cluster-56 mysql-server/root_password password root" | debconf-set-selections
echo "percona-xtradb-cluster-56 mysql-server/root_password_again password root" | debconf-set-selections
echo "percona-xtradb-cluster-56 mysql-server-5.6/start_on_boot boolean false" | debconf-set-selections
echo "percona-xtradb-cluster-server-5.6 percona-xtradb-cluster-server/root_password_again password root" | debconf-set-selections
echo "percona-xtradb-cluster-server-5.6 percona-xtradb-cluster-server/root_password password root" | debconf-set-selections
apt-get -y install socat percona-xtradb-cluster-server-5.6

mkdir -p /usr/lib/galera/
cd /usr/lib/galera/
ln -sf /usr/lib/galera3/libgalera_smm.so .
cd -

mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
exit $?
