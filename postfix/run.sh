#!/bin/bash

echo "RUN!"

mkdir -p /var/log/apache2 /var/log/mysql
chown -R vmail /var/vmail
chown -R www-data /var/www/html/
chown -R mysql /var/lib/mysql
chown -R mysql /var/log/mysql/
chown :syslog /var/log/
chmod 775 /var/log/


cat /etc/php/7.4/apache2/php.ini | grep timezone | grep -ve "^;" || echo "date.timezone=$TIMEZONE" >>  /etc/php/7.4/apache2/php.ini


if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "No mysql database found, initializing!"
    mysqld --initialize-insecure
fi

echo "# Starting MySQL"
/etc/init.d/mysql start;


if [ ! -d "/var/lib/mysql/mail" ]; then
    echo "# No mail database found, creating!"
    mysql -e "create database if not exists mail;"
    mysql -e "CREATE USER 'mail'@'localhost' IDENTIFIED BY 'mail';";
    mysql -e "GRANT ALL PRIVILEGES ON mail.* TO 'mail'@'localhost';"
    mysql -e "flush privileges;"

    mysql -b mail < /tmp/postfixadmin.sql

    PSSW=`doveadm pw -s MD5-CRYPT -p $ADMIN_PASSWD | sed 's/{MD5-CRYPT}//'`
    mysql -e "insert into admin (username, password, active, superadmin, created, modified, token_validity) values('$ADMIN_USERNAME@$DOMAINNAME','$PSSW',1,1, NOW(), NOW(), DATE_ADD(now(), INTERVAL 1 day));" mail
    mysql -e "insert into domain_admins (username, domain, created, active) values('$ADMIN_USERNAME@$DOMAINNAME', 'ALL', NOW(), 1)" mail
    postfixadmin-cli domain add $DOMAINNAME --aliases 0 --mailboxes 0
fi

if [ ! -d "/var/lib/mysql/roundcube" ]; then
    echo "# No roundcube database found, creating!"
    mysql -e "create database if not exists roundcube;"
    mysql -e "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY 'roundcube';";
    mysql -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost';"
    mysql -e "flush privileges;"

    mysql -b roundcube < /tmp/roundcube.sql

    mysql -b roundcube < /var/www/html/mail/plugins/fetchmail/SQL/mysql.initial.sql
    mysql -e "alter table fetchmail add domain varchar(255);" -b roundcube

fi

if [ -z "$MYHOSTNAME" ]; then
    MYHOSTNAME="$HOSTNAME.$DOMAINNAME"
fi
postconf -e myhostname=$MYHOSTNAME
postconf -e mydestination="$MYHOSTNAME, localhost"


#############
#  opendkim
#############
if [[ -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
    opendkim-genkey -b 1024 -D /etc/opendkim/domainkeys/ -d $(hostname -d) -s $(hostname)
fi
if [[ ! -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
    # /etc/postfix/main.cf
    postconf -e milter_protocol=2
    postconf -e milter_default_action=accept
    postconf -e smtpd_milters=inet:localhost:12301
    postconf -e non_smtpd_milters=inet:localhost:12301

    OPENDKIM_CONF_FILE=/etc/opendkim.conf
    OPENDKIM_CONF_ORIG=/etc/opendkim.conf.orig
    if [ -f "$OPENDKIM_CONF_ORIG" ]; then
        # exists
        cat $OPENDKIM_CONF_ORIG > $OPENDKIM_CONF_FILE
    else
        # not exists
        \cp $OPENDKIM_CONF_FILE $OPENDKIM_CONF_ORIG
    fi

    cat >> $OPENDKIM_CONF_FILE <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            /etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOF

    DEFAULT_OPENDKIM_FILE=/etc/default/opendkim
    SOCKET='SOCKET="inet:12301@localhost"'
    grep -qxF $SOCKET $DEFAULT_OPENDKIM_FILE || echo $SOCKET >> $DEFAULT_OPENDKIM_FILE

    TRUSTED_HOSTS_FILE=/etc/opendkim/TrustedHosts
    cat > $TRUSTED_HOSTS_FILE <<EOF
127.0.0.1
localhost
$NETWORK

$DOMAINNAME
*.$DOMAINNAME
EOF

    KEY_TABLE_FILE=/etc/opendkim/KeyTable
    SIGNING_TABLE_FILE=/etc/opendkim/SigningTable

    for keyFile in $(find /etc/opendkim/domainkeys -iname \*.private); do
        if [[ $keyFile =~ "$HOSTNAME.$DOMAINNAME" ]]; then
            DOMAINKEY="$HOSTNAME._domainkey.$DOMAINNAME $DOMAINNAME:$HOSTNAME.$DOMAINNAME:$keyFile"
            grep -qxF "$DOMAINKEY" $KEY_TABLE_FILE || echo "$DOMAINKEY" >> $KEY_TABLE_FILE

            SIGNKEY="$DOMAINNAME $HOSTNAME._domainkey.$DOMAINNAME"
            grep -qxF "$SIGNKEY" $SIGNING_TABLE_FILE || echo "$SIGNKEY" >> $SIGNING_TABLE_FILE
        else
            KEY_FILENAME=${keyFile#*domainkeys/}
            KEY_DOMAIN=${KEY_FILENAME%.private*}
            KEY_HOSTNAME=${KEY_DOMAIN%%.*}
            KEY_PARENT_DOMAIN=${KEY_DOMAIN#*.}

            DOMAINKEY="$KEY_HOSTNAME._domainkey.$KEY_PARENT_DOMAIN $KEY_PARENT_DOMAIN:$KEY_DOMAIN:$keyFile"
            grep -qxF "$DOMAINKEY" $KEY_TABLE_FILE || echo "$DOMAINKEY" >> $KEY_TABLE_FILE

            SIGNKEY="$KEY_PARENT_DOMAIN $KEY_HOSTNAME._domainkey.$KEY_PARENT_DOMAIN"
            grep -qxF "$SIGNKEY" $SIGNING_TABLE_FILE || echo "$SIGNKEY" >> $SIGNING_TABLE_FILE
        fi
    done

    chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private)
    chmod 400 $(find /etc/opendkim/domainkeys -iname *.private)
fi

postconf -e transport_maps=hash:/etc/postfix/transport
postconf -e anvil_status_update_time=7200s
postconf -e default_destination_rate_delay=2s
postconf -e default_destination_concurrency_limit=20
postconf -e local_destination_concurrency_limit=20

postconf -e smtpd_reject_unlisted_recipient=no
postmap /etc/postfix/transport

#SSL
test -d /etc/certs && rm /etc/certs
if [ "$USE_LE_CERTS" == "yes" ] ; then
    ln -s /etc/letsencrypt/live/ /etc/certs

    /etc/init.d/apache2 start
    test -f /etc/apache2/sites-enabled/000-ssl.conf && rm /etc/apache2/sites-enabled/000-ssl.conf

    test -f /etc/apache2/sites-enabled/000-default.conf && rm /etc/apache2/sites-enabled/000-default.conf
    ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default.conf


    certbot --apache -d $HOSTNAME --non-interactive --agree-tos -m webmaster@$HOSTNAME --redirect
    # && certbot renew --dry-run)
else
    ln -s /etc/certs_ext /etc/certs
    test -f /etc/apache2/sites-enabled/000-ssl.conf || ln -s /etc/apache2/sites-available/000-ssl.conf /etc/apache2/sites-enabled/000-ssl.conf
    test -f /etc/apache2/mods-enabled/rewrite.load || ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load
    test -f /etc/apache2/mods-enabled/ssl.load || ln -s /etc/apache2/mods-available/ssl.load /etc/apache2/mods-enabled/ssl.load

    test -f /etc/apache2/sites-enabled/000-default.conf && rm /etc/apache2/sites-enabled/000-default.conf
    ln -s /etc/apache2/sites-available/000-default-manual.conf /etc/apache2/sites-enabled/000-default.conf

    if [ ! -f /etc/certs/$HOSTNAME/cert.pem ] ; then
	echo "#####################################################"
	echo "#####################################################"
	echo "##"
	echo "## ERROR! /etc/certs/$HOSTNAME/cert.pem not found"
	echo "## Put your certs in ${DATA_DIR}/certs/$HOSTNAME/ on docker host, in certbot format (cert.pem, privkey.pem)"
	echo "##"
	echo "####################################################"
	echo "####################################################"
	sleep 10
	
    fi
    /etc/init.d/apache2 start
fi

#############
#  start
#############
echo "Starting services..."
/etc/init.d/opendkim start;/etc/init.d/postfix start;/etc/init.d/rsyslog start;/etc/init.d/cron start;/etc/init.d/spamassassin start

echo Starting dovecot
/usr/sbin/dovecot -F
