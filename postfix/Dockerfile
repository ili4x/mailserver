FROM ubuntu:20.04
LABEL maintainer="Ilya Savin <ilya.v.savin@gmail.com>"

ENV DEBIAN_FRONTEND noninteractive
ENV USERS_QUOTA 50

ARG DOMAINNAME
ENV DOMAINNAME $DOMAINNAME

ARG HOSTNAME
ENV HOSTNNAME $HOSTNAME

ARG LOGO_SVG
ENV LOGO_SVG $LOGO_SVG

ARG TITLE
ENV TTILE $TITLE

ARG RC_LANG
ENV RC_LANG $RC_LANG

ARG USE_LE_CERTS
ENV USE_LE_CERTS $USE_LE_CERTS

ARG ADMIN_USERNAME
ENV ADMIN_USERNAME $ADMIN_USERNAME

RUN echo DOMAINNAME=$DOMAINNAME HOSTNNAME=$HOSTNAME

RUN apt-get update && \
    apt-get install -y wget postfix-mysql \
    dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-sieve dovecot-managesieved \
    spamassassin spamc \
    php-imap php-curl php-ldap php-imagick php-zip rsyslog \
    roundcube aspell-ru \
    libclass-dbi-mysql-perl liblockfile-simple-perl fetchmail \
    mysql-server \
    vim patch \
    telnet nano ca-certificates \
    mailutils dnsutils systemd htop mc \
    sasl2-bin opendkim opendkim-tools && \
    adduser vmail -q --home /var/vmail --uid 1150 --disabled-password --gecos "" && \
    chown :syslog /var/log/ && \
    ln -s /var/www/html/postfixadmin/scripts/postfixadmin-cli /usr/bin/postfixadmin-cli && \
    echo ===== Postfixadmin && \
    wget -q https://github.com/roundcube/roundcubemail/releases/download/1.6.1/roundcubemail-1.6.1-complete.tar.gz && \
    tar -C /var/www/html/ -xf roundcubemail-1.6.1-complete.tar.gz && \
    ln -s /var/www/html/roundcubemail-1.6.1 /var/www/html/mail && \
    rm roundcubemail-1.6.1-complete.tar.gz && \
    echo ===== Roundcube && \
    wget -q https://github.com/postfixadmin/postfixadmin/archive/refs/tags/postfixadmin-3.3.13.tar.gz && \
    tar -C /var/www/html/ -xzf postfixadmin-3.3.13.tar.gz  && \
    rm postfixadmin-3.3.13.tar.gz && \
    ln -s /var/www/html/postfixadmin-postfixadmin-3.3.13/ /var/www/html/postfixadmin && \
    echo ===== Fetchmail && \
    wget -q https://github.com/PF4Public/fetchmail/archive/refs/tags/1.0.13.tar.gz && \
    tar -C /var/www/html/mail/plugins/ -xzf 1.0.13.tar.gz && \
    mv /var/www/html/mail/plugins/fetchmail-1.0.13/ /var/www/html/mail/plugins/fetchmail && \
    chmod 775 /var/log/ 

RUN if [ "x$USE_LE_CERTS" = "xyes" ] ; then apt-get install -y certbot python3-certbot-apache ; else echo "Skip Certbot" ; fi

#postfixadmin

#chmod +x /var/www/html/postfixadmin/scripts/postfixadmin-cli

RUN mkdir /var/www/html/postfixadmin/templates_c
RUN chmod a+w /var/www/html/postfixadmin/templates_c


COPY postfixadmin.sql /tmp
COPY roundcube.sql /tmp

RUN mkdir -p /tmp/roundcube
RUN chmod a+w /tmp/roundcube


COPY run.sh /run.sh
RUN chmod +x /run.sh
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

COPY check_dkim_domains.sh /check_dkim_domains.sh
RUN chmod +x /check_dkim_domains.sh




COPY dovecot /etc/dovecot
COPY postfix /etc/postfix
COPY postfixadmin /var/www/html/postfixadmin
COPY roundcubemail/config /var/www/html/mail/config
COPY roundcubemail/index.php /var/www/html/
RUN mkdir -p /etc/mail/postfixadmin/
COPY fetchmail/fetchmail.conf /etc/mail/postfixadmin/
COPY fetchmail/fetchmail /etc/cron.d/
COPY postfixadmin/check_dkim_domains /etc/cron.d/
COPY spamassassin/local.cf /etc/spamassassin/local.cf
COPY spamassassin/spamassassin /etc/default/spamassassin
COPY dovecot/spamassassin.sieve /etc/dovecot/sieve/spamassassin.sieve
RUN mkdir -p /var/lock/fetchmail
RUN rm /var/www/html/index.html
RUN ln -s /var/www/html/postfixadmin-postfixadmin-3.3.13/ADDITIONS/fetchmail.pl /usr/sbin/fetchmail.pl
COPY apache/000-default.conf /etc/apache2/sites-available/000-default-manual.conf
COPY apache/000-ssl.conf /etc/apache2/sites-available/
RUN ln -s /etc/letsencrypt/live/ /etc/certs

COPY postfixadmin-edit.patch /postfixadmin-edit.patch
RUN patch /var/www/html/postfixadmin/public/edit.php /postfixadmin-edit.patch

COPY logo/*$LOGO_SVG /var/www/html/mail/skins/elastic/images/
RUN test -f /var/www/html/mail/skins/elastic/images/$LOGO_SVG && mv /var/www/html/mail/skins/elastic/images/$LOGO_SVG /var/www/html/mail/skins/elastic/images/logo.svg || echo No logo..

#ini set
RUN sed -i.bak "/^post_max_size = /s/=.*/= 50M/" /etc/php/7.4/apache2/php.ini
RUN sed -i.bak "/^upload_max_filesize = /s/=.*/= 50M/" /etc/php/7.4/apache2/php.ini


RUN echo DOMAINNAME=$DOMAINNAME
RUN sed -i -- "s/\$ADMIN_USERNAME/$ADMIN_USERNAME/g" /etc/dovecot/dovecot.conf
RUN sed -i -- "s/\$DOMAINNAME/$DOMAINNAME/g" /etc/dovecot/dovecot.conf
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /etc/dovecot/dovecot.conf
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /etc/dovecot/conf.d/10-ssl.conf
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /etc/postfix/main.cf
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /var/www/html/mail/config/config.inc.php
RUN sed -i -- "s/\$RC_LANG/$RC_LANG/g" /var/www/html/mail/config/config.inc.php
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /etc/apache2/sites-available/000-default-manual.conf
RUN sed -i -- "s/\$HOSTNAME/$HOSTNAME/g" /etc/apache2/sites-available/000-ssl.conf
RUN sed -i -- "s/\$TITLE/$TITLE/g" /var/www/html/mail/config/config.inc.php

#apache ssl
RUN ln -s /etc/apache2/mods-available/socache_shmcb.load /etc/apache2/mods-enabled/socache_shmcb.load


VOLUME [ "/var/log/", "/var/vmail/", "/var/lib/mysql" ]

EXPOSE 25 80 110 143 465 993 995

ENTRYPOINT /run.sh
