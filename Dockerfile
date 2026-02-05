FROM nginx:1.29.5 AS opensafely-proxy
# Default orgs, must be pipe separated as are fed into a regex match
# Can be overridden via run time env var
ENV ORGS=opensafely|opensafely-core|opensafely-actions
ENV PORT=8080
COPY nginx.conf /etc/nginx/nginx.conf
COPY *.conf.template /etc/nginx/templates/
