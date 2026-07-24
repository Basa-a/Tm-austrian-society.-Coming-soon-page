FROM nginx:1.28-alpine

COPY index.html /usr/share/nginx/html/

COPY nginx/app_https.conf /etc/nginx/conf.d/default.conf
# COPY nginx/app_http.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=3s CMD wget --no-check-certificate -q -O /dev/null http://localhost/ || exit 1


