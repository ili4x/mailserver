#!/bin/bash

mkdir -p /backup

if [ "x$BACKUP_DAYS" == "x" ] ; then
        BACKUP_DAYS=7
fi

find /backup/ -type f -mtime +$BACKUP_DAYS -name '*.gz' -execdir rm -- '{}' \;

mysqldump --databases mail roundcube > backup.sql
tar -czf /backup/backup-`date +"%Y-%m-%d_%H-%M-%S"`.tar.gz /var/vmail backup.sql &> /dev/null
rm backup.sql
