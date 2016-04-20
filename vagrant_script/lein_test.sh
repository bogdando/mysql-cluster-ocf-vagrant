#!/bin/sh
# Pull images to new location, which is the shared docker volume /jepsen
# Launch lein to test a given app ($1) and a given test ($2) or all.
# Protect from an incident running on hosts which aren't n1, n2, etc.
# Stop & remove the main jepsen container, if env $PURGE=true
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ "$1" ] || exit 1
unit="/lib/systemd/system/docker.service"
if ! grep -q '^ExecStart.*\-g' "${unit}"
then
  echo "Patch docker service unit"
  sed -ie 's_^ExecStart.*[^\-g]_& -g /jepsen_' "${unit}"
  systemctl daemon-reload && systemctl restart docker
fi
if ! docker images | grep -q 'pandeiro/lein'
then
  echo "Pull lein container"
  docker pull pandeiro/lein
fi

if [ "${PURGE}" = "true" ]; then
  docker stop jepsen && docker rm -f -v jepsen
fi

# Run lein to make a custom galera dependency build
docker stop jepsen-build && docker rm -f -v jepsen-build
echo "Make a custom galera jar build"
docker run -it --rm \
  -v /jepsen/jepsen/galera:/app \
  --entrypoint /bin/bash \
  --name jepsen-build -h jepsen \
  pandeiro/lein:latest -c "lein deps && lein compile && lein uberjar; sync"
sync

# FIXME(bogdando) remove those customs, when build is not required anymore
# Run lein to make a custom jepsen build
docker stop jepsen-build && docker rm -f -v jepsen-build
echo "Make a custom jepson jar build"
docker run -it --rm \
  -v /jepsen/jepsen/jepsen:/app \
  --entrypoint /bin/bash \
  --name jepsen-build -h jepsen \
  pandeiro/lein:latest -c "lein deps && lein compile && lein uberjar; sync"
sync

# Run lein for jepsen tests, using the custom build from the target dir mounted
# Ignore exit code as it may fail. Distributed systems are faily with jepsen...
echo "Run lein test"
docker run --stop-signal=SIGKILL -itd \
  -v /etc/hosts:/etc/hosts:ro \
  -v /root/.ssh:/root/.ssh:ro \
  -v /jepsen/jepsen/$1:/app \
  -v /jepsen/jepsen/jepsen/target:/custom:ro \
  -v /jepsen/jepsen/galera/target:/custom2:ro \
  -v /jepsen/logs:/app/store \
  --entrypoint /bin/bash \
  --name jepsen -h jepsen \
  pandeiro/lein:latest
if [ "${PURGE}" = "true" ]; then
  # install dependency
  docker exec -it jepsen bash -c "apt-get update"
  docker exec -it jepsen bash -c "apt-get -y install gnuplot-qt"
fi
# copy custom jar builds
docker exec -it jepsen bash -c "mkdir -p resources/jepsen/galera/0.1.0-SNAPSHOT"
docker exec -it jepsen bash -c "cp -f /custom2/jepsen.galera-0.1.0-SNAPSHOT*  resources/jepsen/galera/0.1.0-SNAPSHOT/"
docker exec -it jepsen bash -c "mkdir -p resources/jepsen/jepsen/0.1.0-SNAPSHOT"
docker exec -it jepsen bash -c "cp -f /custom/jepsen-0.1.0-SNAPSHOT*  resources/jepsen/jepsen/0.1.0-SNAPSHOT/"

testcase="lein test"
[ "${2}" ] && testcase="${testcase} :only jepsen.${1}-test/${2}"
docker exec -it jepsen bash -c "lein deps && lein compile && ${testcase}"
echo "Test exited with $?, but it is OK anyway"
sync
exit 0
