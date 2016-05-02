#!/bin/sh
# Install the mariadb galera 10 packages from debian jessie.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
echo 'deb http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.0/debian jessie main' > /etc/apt/sources.list.d/mariadb.list
echo "Package: *
Pin: origin sfo1.mirrors.digitalocean.com
Pin-Priority: 1000" > /etc/apt/preferences.d/00mariadb.pref
echo "mariadb-galera-server-10.0 mysql-server/root_password password root" | debconf-set-selections
echo "mariadb-galera-server-10.0 mysql-server/root_password_again password root" | debconf-set-selections
apt-get update
apt-get -y install socat mariadb-galera-server percona-xtrabackup galera-3 netcat-openbsd

mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
exit $?
