#!/bin/sh
# Install the mariadb galera, mysql server packages of a given versions ($1, $2),
# if requested.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ $1 ] || exit 1
[ "$1" = "false" ] && exit 0

#TODO
exit 0
mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
service mysql stop
exit $?
