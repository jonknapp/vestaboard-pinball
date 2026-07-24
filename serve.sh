#!/bin/bash
podman run --rm -p 8000:80 \
  -v "$(pwd)/public:/usr/share/nginx/html:z" \
  -v "$(pwd)/nginx.dev.conf:/etc/nginx/conf.d/default.conf:z" \
  nginx:alpine
