#!/bin/bash
podman run --rm -p 8000:80 -v "$(pwd)/public:/usr/share/nginx/html:z" nginx:alpine
