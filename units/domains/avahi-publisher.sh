#!/bin/sh -e

IP=$(ip route get 1 | awk '{print $7;exit}')
SITES=$(ls /usr/local/etc/sites)

if [[ $SITES != "$HOSTNAME.local.conf" ]]; then
  for file in $SITES; do
    if [[ $file == *\.local.conf ]]; then
      domain="$(basename $file .conf)"
      if [[ $domain != "$HOSTNAME.local" ]]; then
        avahi-publish -a $domain -R $IP &
      fi
    fi
  done

  wait -n
  exit $?
fi
