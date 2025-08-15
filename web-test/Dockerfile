FROM nginx:alpine

COPY --chown=nginx:nginx www/ /usr/share/nginx/html/

RUN find /usr/share/nginx/html -type d -exec chmod 0755 {} \; && \
    find /usr/share/nginx/html -type f -exec chmod 0644 {} \;
