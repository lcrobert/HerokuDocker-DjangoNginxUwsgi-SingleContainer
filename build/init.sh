#!/bin/bash
#source /nvm/nvm.sh
envsubst < /home/pysaweb/pysaweb_nginx_template.conf > /home/pysaweb/pysaweb_nginx.conf

rm -f /etc/nginx/sites-available/default
rm -f /etc/nginx/sites-enabled/default 

exec /usr/bin/supervisord
