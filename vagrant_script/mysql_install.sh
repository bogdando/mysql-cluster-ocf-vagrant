#!/bin/sh
# Install the codership mysql server packages of a given versions ($1, $2),
# if requested. Note, that is not the percona packages.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ $1 ] || exit 1
[ "$1" = "false" ] && exit 0

apt-get update
echo "mysql-server-5.6 mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server-5.6 mysql-server/root_password_again password root" | debconf-set-selections
echo "mysql-server-5.6 mysql-server-5.6/start_on_boot boolean false" | debconf-set-selections
apt-get -y install socat mysql-server

file1="galera-$1-amd64.deb"
wget "https://launchpad.net/galera/3.x/$1/+download/$file1" -O "/tmp/$file1"

# extract the version prefix
v1="${2%*.*.*}"
file2="mysql-server-wsrep-$2-amd64.deb"
wget "https://launchpad.net/codership-mysql/$v1/$2/+download/$file2" -O "/tmp/$file2"
dpkg --force-all -i "/tmp/$file1" "/tmp/$file2"

mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
exit $?
