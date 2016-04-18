#!/bin/sh
# Install the mariadb mysql server packages of a given versions ($1, $2),
# if requested. Note, that is not the percona or codership galera packages.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ $1 ] || exit 1
[ "$1" = "false" ] && exit 0

# TODO
exit 0
exit $?
