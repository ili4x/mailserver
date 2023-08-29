#!/bin/bash

mkdir -p /backup

if [ "x$BACKUP_DAYS" == "x" ] ; then
        BACKUP_DAYS=7
fi

find /backup/ -type f -mtime +$BACKUP_DAYS -name '*.gz' -execdir rm -- '{}' \;

FN=backup-`date +"%Y-%m-%d_%H-%M-%S"`.tar.gz

cd /backup

mysqldump --databases mail roundcube > backup.sql
tar -czf /backup/$FN /var/vmail backup.sql &> /dev/null
rm backup.sql

if [ -n "$BACKUP_UPLOAD_URL" ] ; then
	curl -k -T $FN $BACKUP_UPLOAD_URL --user $BACKUP_UPLOAD_USER:$BACKUP_UPLOAD_PASSWD
	if [ "$BACKUP_UPLOAD_DELETE" == "yes" ] ; then
		rm $FN
	fi
fi