#!/bin/sh -e

IP=$(ip route get 1 | awk '{print $7;exit}')

for domain in $(ls /usr/local/etc/domains); do
  if [[ $domain == *\.local ]]; then
    avahi-publish -a $domain -R $IP &
  fi
done

wait -n
exit $?
