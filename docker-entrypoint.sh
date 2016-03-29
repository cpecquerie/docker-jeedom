#!/bin/bash
#!/bin/bash

JEEDOM_BASE_DIR=/var/www/html

set_config() {
    key="$1"
    value="$2"
    php_escaped_value="$(php -r 'var_export($argv[1]);' "$value")"
    sed_escaped_value="$(echo "$php_escaped_value" | sed 's/[\/&]/\\&/g')"
    sed -ri "s/((['\"])$key\2\s*=>\s*)(['\"]).*\3/\1$sed_escaped_value/" ./core/config/common.config.php
}

prepare_database() {

    if [ -n "$MYSQL_PORT_3306_TCP" ]; then
        JEEDOM_DB_HOST='mysql'
    else
        echo >&2 "WARNING: MYSQL_PORT_3306_TCP not found, meaning linked mysql container doesn't exist."
    fi

    # if we're linked to MySQL, and we're using the root user, and our linked
    # container has a default "root" password set up and passed through... :)
    : ${JEEDOM_DB_USER:=root}
    if [ "$JEEDOM_DB_USER" = 'root' ]; then
	: ${JEEDOM_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
    fi
    : ${JEEDOM_DB_NAME:=jeedom}

    if [ -z "$JEEDOM_DB_PASSWORD" ]; then
	echo >&2 'error: missing required JEEDOM_DB_PASSWORD environment variable'
	echo >&2 '  Did you forget to -e JEEDOM_DB_PASSWORD=... ?'
	echo >&2
	echo >&2 '  (Also of interest might be JEEDOM_DB_USER and JEEDOM_DB_NAME.)'
	exit 1
    fi

    set_config 'host' "mysql"
    set_config 'username' "$JEEDOM_DB_USER"
    set_config 'password' "$JEEDOM_DB_PASSWORD"
    set_config 'dbname' "$JEEDOM_DB_NAME"
    set_config 'port' "$MYSQL_PORT_3306_TCP"

    TERM=dumb php -- "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" "$JEEDOM_DB_NAME" "$JEEDOM_DB_USER" "$JEEDOM_DB_PASSWORD" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)
$mysql_root_password = $argv[1];

$stderr = fopen('php://stderr', 'w');
$maxTries = 10;
do {
    $mysql = new mysqli('mysql', 'root', $mysql_root_password, '', (int)getenv('MYSQL_PORT_3306_TCP'));
    if ($mysql->connect_error) {
	fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
	--$maxTries;
	if ($maxTries <= 0) {
	    exit(1);
	}
	sleep(3);
    }
} while ($mysql->connect_error);

$jeedom_db_name = $mysql->real_escape_string($argv[2]);
$jeedom_db_username = $mysql->real_escape_string($argv[3]);
$jeedom_db_password = $mysql->real_escape_string($argv[4]);

$query = "CREATE DATABASE IF NOT EXISTS `$jeedom_db_name`";
if (!$mysql->query($query)) {
    fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\nquery=$query\n");
    $mysql->close();
    exit(1);
}
$query = "GRANT ALL PRIVILEGES ON `$jeedom_db_name`.* TO `$jeedom_db_username`@`%` IDENTIFIED BY '$jeedom_db_password'";
if (!$mysql->query($query)) {
    fwrite($stderr, "\n" . 'MySQL "GRANT" Error: ' . $mysql->error . "\nquery=$query\n");
    $mysql->close();
    exit(1);
}

$mysql->close();
EOPHP

    php "${JEEDOM_BASE_DIR}/install/install.php" mode=force
}

echo 'INFO: Start init'

# Configure Jeedom if not done yet
CONFIG_FILE=${JEEDOM_BASE_DIR}/core/config/common.config.php

if [ -d /var/www/html/core ]; then
	echo 'INFO: Jeedom is already install'
else
    echo "INFO: Downloading Jeedom archive..."
	mkdir -p /var/www/html
	rm -rf /root/core-*
	wget https://github.com/jeedom/core/archive/stable.zip -O /tmp/jeedom.zip
	unzip -q /tmp/jeedom.zip -d /root/
	cp -R /root/core-*/* /var/www/html/
    cd "$JEEDOM_BASE_DIR"
    cp ./core/config/common.config.sample.php ./core/config/common.config.php
    
    # Take care of database
    prepare_database
        
    echo "INFO: Jeedom installed."
fi

echo 'INFO: All init complete'
chmod 777 /dev/tty*

# Make sure access rights are ok
chmod -R 755 "$JEEDOM_BASE_DIR"
chown -R www-data:www-data "$JEEDOM_BASE_DIR"

exec "$@"

