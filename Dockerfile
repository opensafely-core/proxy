FROM nginx:1.19.9
ENV PORT=8080
# Default orgs, must be pipe separated as are fed into a regex match
# Can be overridden via run time env var
ENV ORGS=opensafely|opensafely-core|opensafely-actions|graphnet-opensafely
COPY *.conf.template /etc/nginx/templates/
# uncomment to build a debug version locally
#CMD ["nginx-debug", "-g", "daemon off; error_log /var/log/nginx/error.log debug;"]
