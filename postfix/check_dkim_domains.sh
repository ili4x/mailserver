#!/bin/bash

test -f /tmp/neetupdatedkim || exit
rm /tmp/neetupdatedkim

mysql mail -se "select domain from domain" | tail -n +1 | while read domain ; do (cat /etc/opendkim/SigningTable | grep "^$domain " > /dev/null || (echo adding $domain ; touch /tmp/hasnewdomains ; echo "$domain" `cat /etc/opendkim/KeyTable | head -n 1 | awk '{ print $1 }'` >> /etc/opendkim/SigningTable)) ; done

test -f /tmp/hasnewdomains && (/etc/init.d/postfix restart && rm /tmp/hasnewdomains)
