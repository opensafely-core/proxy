FROM nginx:1.19.3
COPY default.conf.template /etc/nginx/templates/ 
#CMD ["nginx-debug", "-g", "daemon off;"]
