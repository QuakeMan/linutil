#!/bin/sh
apt-get install -y aptitude
aptitude update
aptitude upgrade
aptitude install -y nginx php-fpm php-mysql default-mysql-server thin ruby htop php-mbstring
[ ! -e "/tmp/redmine-4.1.1.tar.gz" ] && wget https://www.redmine.org/releases/redmine-4.1.1.tar.gz -P /tmp/
mkdir -p /redminefolder
[ ! -e "/redminefolder/config/database.yml" ] && tar xzfo /tmp/redmine-4.1.1.tar.gz --strip-components=1 -C /redminefolder
cd /redminefolder
aptitude install -y ruby-dev build-essential zlib1g-dev libmagickcore-dev libmagickwand-dev default-libmysqlclient-dev bundler imagemagick libgdbm-dev libgdbm-compat-dev
bundle config set without 'development test sqlite postgresql'
#[ ! -e "/redminefolder/config/database.yml" ] && cp config/database.yml.example config/database.yml
[ ! -e "~/.gemrc" ] && echo 'install: --no-rdoc --no-ri
update: --no-rdoc --no-ri
' > ~/.gemrc
gem update
mysql -e "CREATE DATABASE IF NOT EXISTS redmine CHARACTER SET utf8mb4;"
mysql -e "GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'localhost' IDENTIFIED BY 'pass';"

mkdir -p /var/log/thin
mkdir -p /var/run/thin
mkdir -p /redminefolder/public/plugin_assets
chown -R www-data:www-data /var/run/thin

chown -R www-data:www-data /redminefolder/tmp
chown -R www-data:www-data /redminefolder/log
chown -R www-data:www-data /redminefolder/public/plugin_assets
chown -R www-data:www-data /redminefolder/files

echo '---
chdir: "/redminefolder"
environment: production
timeout: 30
log: "/var/log/thin/redmine.log"
pid: "/var/run/thin/redmine.pid"
max_conns: 1024
max_persistent_conns: 100
require: []
wait: 30
threadpool_size: 20
socket: "/var/run/thin/redmine.sock"
daemonize: true
user: www-data
group: www-data
servers: 1
prefix: "/redmineurl"
' > /etc/thin2.5/redmine.yml

echo 'production:
  adapter: mysql2
  database: redmine
  host: localhost
  username: redmine
  password: pass
  encoding: utf8
' >  /redminefolder/config/database.yml


[ ! -e "/redminefolder/config/configuration.yml" ] && cp config/configuration.yml.example config/configuration.yml
bundle install

rake generate_secret_token
RAILS_ENV=production rake db:migrate

echo '
!!!! add this to config/routes.rb

Redmine::Utils::relative_url_root = "/redmineurl"

!!!! add to nginx config next section
'
echo 'upstream thin_server {
server unix:/var/run/thin/redmine.0.sock;
}
'
echo '!!!! into "server" section
location /redmineurl {
alias /redminefolder/public;
try_files $uri @thin;
}
location @thin {
proxy_pass http://thin_server;
}
'
echo '#Type Path        Mode UID      GID      Age Argument
    d /run/thin    0755 www-data www-data -   -
' > /usr/lib/tmpfiles.d/thin.conf
