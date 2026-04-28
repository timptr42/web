FROM nginx:1.27-alpine

ARG BUILD_ID=unknown
LABEL build_id="${BUILD_ID}"

RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY app/ /usr/share/nginx/html/

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:80/api/healthz || exit 1
