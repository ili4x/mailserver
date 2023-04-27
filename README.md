# Postfix+Dovecot+RoundCube MailServer
Based on [kipkaev55/postfix-dovecot-roundcube](https://github.com/kipkaev55/postfix-dovecot-roundcube)
### Changes
* Updated to Ubunto 20.04
* Using latest version of Roundcube (1.6.1)
* Using latest version of Postfixadmin (3.3.13)
* Added sieve plugin for mail filtering & forward (user settings in Roundcube)
* Added fetchmail for fetching mail from other POP3/IMAP servers (user settings in Roundcube)
* Added certbot. Using Letsencrypt certs for apache/postfix/dovecot.
* Added spamassassin.
* Added backup script.
### How to use
* Install [docker-compose](https://docs.docker.com/compose/install/)
* Copy .env.example and custom it
```js
cp .env.example .env
```
* Run docker-composer for mailserver
```js
docker-compose build mailserver
docker-compose up -d mailserver
```
