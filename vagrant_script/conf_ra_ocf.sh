#!/bin/sh
STORAGE=${STORAGE:-/tmp}
mkdir -p $STORAGE
[ "${OCF_RA_PROVIDER}" = "none" ] && exit 0
if [ "${UPLOAD_METHOD}" = "copy" ] ; then
  [ "${OCF_RA_PATH}" ] || exit 1
  echo "Get the OCF RA from ${OCF_RA_PATH}"
  cp -f "${OCF_RA_PATH}" "${STORAGE}/${OCF_RA_PROVIDER}"
elif [ "${UPLOAD_METHOD}" = "none" ] ; then
  echo "Do not upload the OCF RA"
else
  echo "Download the OCF RA from the stable branch"
  wget "${OCF_RA_PATH}"  -O "${STORAGE}/${OCF_RA_PROVIDER}"
fi
chmod +x "${STORAGE}/${OCF_RA_PROVIDER}"
mkdir -p "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}"
cp -f "${STORAGE}/${OCF_RA_PROVIDER}" "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER}"

# FIXME(bogdando) remove fuel specific OCF RA
mkdir -p /usr/lib/ocf/resource.d/fuel
wget https://raw.githubusercontent.com/openstack/fuel-library/master/files/fuel-ha-utils/ocf/ocf-fuel-funcs \
-O /usr/lib/ocf/resource.d/fuel/ocf-fuel-funcs

# Prepare for debug logs
dir=/tmp/mysql.ocf.ra.debug
mkdir -p $dir
touch ${dir}/log
chmod 700 ${dir}/log
exit 0
