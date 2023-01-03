#!/bin/sh

avahi-publish -a $1.local -R $(ip route get 1 | awk '{print $7;exit}')
