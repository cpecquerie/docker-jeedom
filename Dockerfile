FROM debian:latest

MAINTAINER edouard@kleinhans.info

ENV SHELL_ROOT_PASSWORD jeedom

RUN apt-get update && apt-get install -y \
build-essential \
wget \
unzip \
curl \
openssh-server \
supervisor \
cron \
mysql-client \
nginx-light \
php5-cli \
php5-common \
php5-curl \
php5-dev \
php5-fpm \
php5-json \
php5-mysql \
php-pear \
php5-oauth \
net-tools \
locales \
ca-certificates \
Dialog \
sudo \
make \
htop \
nano \
ntp \
usb-modeswitch \
python-serial \
ow-shell 

####################################################################SYSTEM#######################################################################################

RUN echo "root:${SHELL_ROOT_PASSWORD}" | chpasswd && \
  sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

RUN mkdir -p /var/run/sshd /var/log/supervisor
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN dpkg-reconfigure locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8

ENV LC_ALL C.UTF-8

RUN apt-get autoremove
RUN apt-get clean

####################################################################NGINX#######################################################################################

COPY nginx_default /etc/nginx/sites-available/default
RUN touch /etc/nginx/sites-available/jeedom_dynamic_rule && chmod 777 /etc/nginx/sites-available/jeedom_dynamic_rule

RUN echo "daemon off;" >> /etc/nginx/nginx.conf

####################################################################PHP#########################################################################################

RUN sed -i "s/max_execution_time = 30/max_execution_time = 600/g" /etc/php5/fpm/php.ini
RUN sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 1G/g" /etc/php5/fpm/php.ini
RUN sed -i "s/post_max_size = 8M/post_max_size = 1G/g" /etc/php5/fpm/php.ini
RUN sed -i "s/expose_php = On/expose_php = Off/g" /etc/php5/fpm/php.ini
RUN sed -i "s/pm.max_children = 5/pm.max_children = 20/g" /etc/php5/fpm/pool.d/www.conf
RUN echo "extension=oauth.so" >> /etc/php5/fpm/php.ini

####################################################################JEEDOM#######################################################################################
RUN echo "www-data ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)
RUN echo "* * * * * su --shell=/bin/bash - www-data -c '/usr/bin/php /var/www/html/core/php/jeeCron.php' >> /dev/null" | crontab -

####################################################################SYSTEM CLEAN#################################################################################
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD bashrc /root/.bashrc

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html/jeedom

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord"]

EXPOSE 22 80 1886  

#1886 : MQTT

