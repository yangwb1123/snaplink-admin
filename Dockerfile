# Single-stage image: serves a pre-built Flutter web bundle.
#
# This network has had trouble reaching Flutter's build-image registries, so
# the Flutter build deliberately does NOT happen inside Docker. Run this
# first, on the host, before building the image:
#
#   flutter build web --release --base-href=/app/
#
# See DEPLOY.md for the full deployment walkthrough.
FROM nginx:alpine

COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
