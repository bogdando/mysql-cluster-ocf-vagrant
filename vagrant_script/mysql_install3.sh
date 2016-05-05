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
apt-get -y install socat mariadb-galera-server percona-xtrabackup galera-3 netcat-openbsd libev4

# w/a https://jira.mariadb.org/browse/MDEV-9708 and "xbstream: Can't create/write to file '././backup-my.cnf' (Errcode: 17 - File exists)"
wget https://github.com/percona/percona-xtradb-cluster/raw/5.6/scripts/wsrep_sst_xtrabackup-v2.sh -O /usr/bin/wsrep_sst_xtrabackup-v2
wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.3.4/binary/debian/wily/x86_64/percona-xtrabackup_2.3.4-1.wily_amd64.deb \
-O /tmp/percona-xtrabackup_2.3.4-1.wily_amd64.deb
dpkg -i --force-all /tmp/percona-xtrabackup_2.3.4-1.wily_amd64.deb

mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
exit $?
