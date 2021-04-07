FROM nginx:1.19.9
ENV RESOLVER=127.0.0.1 PORT=8080
COPY *.conf.template /etc/nginx/templates/
# uncomment to build a debug version locally
#CMD ["nginx-debug", "-g", "daemon off; error_log /var/log/nginx/error.log debug;"]
