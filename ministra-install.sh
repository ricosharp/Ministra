#!/bin/bash

# Before executing, make sure the ministra-<version>.zip file is in the same directory as this script. Also make sure this script has execute permissions (chmod +x ministra.sh).

# Get a password for the mysql root user.
while [ $MYSQL_PASSWORD != $MYSQL_PASSWORD_VERIFY ]
    do
        printf "Enter a mysql root password: "
        read -s MYSQL_PASSWORD
        printf "\nConfirm the mysql root password: "
        read -s MYSQL_PASSWORD_VERIFY
        printf "\n"

        if [ $MYSQL_PASSWORD != $MYSQL_PASSWORD_VERIFY ]
            then
                printf "Password do not match. Please try again\n"
        fi
    done

# Set variable to prevent mysql password prompt.
export DEBIAN_FRONTEND=noninteractive

# Check for updates to system.
apt update -y

# Install system updates.
apt upgrade -y

# Install nginx. Done seperately as installing with apache causes issues.
apt install nginx -y

# Install the rest of the required packages.
apt install apache2 php7.0-mcrypt php7.0-mbstring nginx memcached mysql-server php php-mysql php-pear nodejs libapache2-mod-php php-curl php-imagick php-sqlite3 unzip -y

pear channel-discover pear.phing.info

pear install -Z phing/phing

# Mysql Configuration
printf "Configuring mysql\n"
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';"
printf "sql_mode=\"\"\n" | tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -u root -p"$MYSQL_PASSWORD" -e "CREATE DATABASE stalker_db;"
mysql -u root -p"$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON stalker_db.* TO 'stalker'@'localhost' IDENTIFIED BY '1' WITH GRANT OPTION;"
printf "Restarting mysql\n"
systemctl restart mysql

# PHP Configuration
phpenmod mcrypt
printf "short_open_tag = On\n" | tee -a /etc/php/7.0/apache2/php.ini

# Apache Configuration
printf "Configuring apache\n"
a2enmod rewrite
printf "<VirtualHost *:88>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www
        <Directory /var/www/stalker_portal/>
                Options -Indexes -MultiViews
                AllowOverride ALL
                Require all granted
        </Directory>
        <Directory /var/www/player>
                Options -Indexes -MultiViews
                AllowOverride ALL
                #Require all granted
                DirectoryIndex index.php index.html
        </Directory> 
		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>\n" | tee /etc/apache2/sites-available/000-default.conf
sed -i 's/Listen 80/Listen 88/' /etc/apache2/ports.conf
printf "Restarting apache\n"
systemctl restart apache2

# Nginx Configuration
printf "server {
	listen 80;
	server_name localhost;

root /var/www;
    location ^~ /player {
        root /var/www/player;
        index index.php;
        rewrite ^/player/(.*) /player/$1 break;
        proxy_pass http://127.0.0.1:88/;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
    }

	location / {
	proxy_pass http://127.0.0.1:88/;
	proxy_set_header Host \$host:\$server_port;
	proxy_set_header X-Real-IP \$remote_addr;
	}

	location ~* \.(htm|html|jpeg|jpg|gif|png|css|js)$ {
	root /var/www;
	expires 30d;
	}
}\n" | tee /etc/nginx/sites-available/default
printf "Restarting nginx\n"
systemctl restart nginx

# Install and configure NPM
apt install npm -y
npm install -g npm@2.15.11
ln -s /usr/bin/nodejs /usr/bin/node

# Unzip ministra to /var/www
unzip ministra-5.6.0.zip -d /var/www/

# Run the deployment script
cd /var/www/stalker_portal/deploy
phing
cd ~

# Clean up environment variables (this should occur after a log out anyway)
printf "Cleaning up environment\n"
unset DEBIAN_FRONTEND

# Links that helped create this script:
# https://stackoverflow.com/questions/13814413/how-to-auto-login-mysql-in-shell-scripts
# https://techoverflow.net/2019/03/16/how-to-solve-permission-denied-error-when-trying-to-echo-into-a-file/
# https://www.percona.com/blog/2016/03/16/change-user-password-in-mysql-5-7-with-plugin-auth_socket/
# https://unix.stackexchange.com/questions/184631/bash-ubuntu-strings-in-while-loops
