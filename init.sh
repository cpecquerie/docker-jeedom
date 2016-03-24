#!/bin/bash
echo 'Start init'

if [ -z ${ROOT_PASSWORD} ]; then
	echo "Use default password : jeedom"
	echo "root:jeedom" | chpasswd
else
	echo "root:${ROOT_PASSWORD}" | chpasswd
fi

if [ -d /var/www/html/core ]; then
	echo 'Jeedom is already install'
else
	mkdir -p /var/www/html
	echo 'Jeedom not found install it'
	rm -rf /root/core-*
	wget https://github.com/jeedom/core/archive/stable.zip -O /tmp/jeedom.zip
	unzip -q /tmp/jeedom.zip -d /root/
	cp -R /root/core-*/* /var/www/html/
	cp -R /root/core-*/.htaccess /var/www/html/
fi

echo 'All init complete'
chmod 777 /dev/tty*
chmod 755 -R /var/www/html
chown -R www-data:www-data /var/www/html

echo 'Launch cron'
service cron start

echo 'Launch php-fpm'
service php5-fpm start

echo 'Launch nginx'
service nginx start

echo 'Launch Jeedom'
service jeedom start

/usr/bin/supervisord

