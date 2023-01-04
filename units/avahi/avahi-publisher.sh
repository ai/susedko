#!/bin/sh -e

IP=$(ip route get 1 | awk '{print $7;exit}')

for file in $(ls /usr/local/etc/sites); do
  if [[ $file == *\.local.conf ]]; then
    domain="$(basename $file .conf)"
    if [[ $file != $HOSTNAME]]; then
      avahi-publish -a $domain -R $IP &
    fi
  fi
done

wait -n
exit $?
