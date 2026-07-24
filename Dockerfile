FROM nginx:alpine

COPY public /usr/share/nginx/html

RUN nginx -t
