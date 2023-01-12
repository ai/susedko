#!/bin/sh -e

IP=$(ip route get 1 | awk '{print $7;exit}')
SITES=$(ls /usr/local/etc/nginx/conf.d/)

for file in $SITES; do
  if [[ $file == *\.local.conf ]]; then
    domain="$(basename $file .conf)"
    if [[ $domain != "$HOSTNAME.local" ]]; then
      avahi-publish -a $domain -R $IP &
      published=1
    fi
  fi
done

if [[ $published ]]; then
  wait -n
  exit $?
fi
