FROM nginx:1.19.3
RUN rm -f /etc/nginx/conf.d/default.conf
COPY proxy.conf.template /etc/nginx/templates/ 
