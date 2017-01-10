#!/bin/sh -e
# Install the latest codership mysql server packages
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

apt-key adv --keyserver keyserver.ubuntu.com --recv BC19DDBA
echo "deb http://releases.galeracluster.com/ubuntu xenial main" > /etc/apt/sources.list.d/galera.list

apt-get update
echo "mysql-server-5.6 mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server-5.6 mysql-server/root_password_again password root" | debconf-set-selections
echo "mysql-server-5.6 mysql-server-5.6/start_on_boot boolean false" | debconf-set-selections
apt-get -y --no-install-recommends install socat galera-3 galera-arbitrator-3 mysql-wsrep-5.6

mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
sync
