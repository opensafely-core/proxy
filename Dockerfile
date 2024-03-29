FROM nginx:1.25.4 AS opensafely-proxy
ENV PORT=8080
# Default orgs, must be pipe separated as are fed into a regex match
# Can be overridden via run time env var
ENV ORGS=opensafely|opensafely-core|opensafely-actions
COPY *.conf.template /etc/nginx/templates/


FROM opensafely-proxy AS proxy-debug
CMD ["nginx-debug", "-g", "daemon off; error_log /var/log/nginx/error.log debug;"]
