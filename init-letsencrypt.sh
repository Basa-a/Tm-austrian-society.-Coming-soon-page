#!/bin/bash
# One-time bootstrap: obtains the initial Let's Encrypt certificate.
# Run this once on the VPS before the first `docker compose up -d`.
# Ongoing renewal is handled automatically by the `certbot` service in
# docker-compose.yml, so this script does not need to run again.
set -e

domains=(turkmenistan-kultur.at www.turkmenistan-kultur.at.com)
rsa_key_size=4096
data_path="./certbot"
staging=0 # set to 1 first to test against Let's Encrypt's staging server and avoid rate limits

if [ -d "$data_path/conf/live/${domains[0]}" ]; then
  read -p "Existing certificate data found for ${domains[0]}. Continue and replace it? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for ${domains[0]} ..."
mkdir -p "$data_path/conf/live/${domains[0]}"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
    -keyout '/etc/letsencrypt/live/${domains[0]}/privkey.pem' \
    -out '/etc/letsencrypt/live/${domains[0]}/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker compose up --force-recreate -d web
echo

echo "### Deleting dummy certificate for ${domains[0]} ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/${domains[0]} && \
  rm -Rf /etc/letsencrypt/archive/${domains[0]} && \
  rm -Rf /etc/letsencrypt/renewal/${domains[0]}.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for ${domains[*]} ..."
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

case "$staging" in
1) staging_arg="--staging" ;;
*) staging_arg="" ;;
esac

docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --register-unsafely-without-email \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker compose exec web nginx -s reload
