FROM python:3.12-slim AS build

# Keep the SDK version and archive checksum together. Flutter's Linux release
# archives are xz-compressed; pinning both prevents a moving build toolchain
# from silently changing the production artifact.
ARG FLUTTER_VERSION=3.47.1
ARG FLUTTER_SHA256=a1d8166c0309267cb7dc99f1424eecf08b86946ad3b50723c6f59945964aea45
ARG SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api

WORKDIR /app

# Install Flutter SDK dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
RUN curl -fsSL --retry 3 --retry-all-errors \
    -o /tmp/flutter.tar.xz \
    https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
    && tar xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

# Flutter is shipped as a Git checkout owned by root in this build stage.
RUN git config --global --add safe.directory /opt/flutter \
    && /opt/flutter/bin/flutter config --enable-web \
    && /opt/flutter/bin/flutter precache --web

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Build the Flutter app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
# Code splitting: six product entries compile to separate deferred chunks;
# dart2wasm does not emit deferred chunks yet, so the image builds dart2js.
RUN flutter build web --release --base-href=/app/ \
    --dart-define=SNAPLINK_ADMIN_OAUTH_RESOURCES="${SNAPLINK_ADMIN_OAUTH_RESOURCES}"

# ── Production stage ──
FROM nginx:alpine

ENV SNAPLINK_UPSTREAM=http://snaplink:8080
ENV SNAPLINK_SERVER_NAME=snaplink
ENV SNAPLINK_CA=/etc/ssl/certs/ca-certificates.crt
ENV SNAPLINK_BILLING_UPSTREAM=
ENV SNAPLINK_BILLING_SERVER_NAME=snaplink-billing
ENV SNAPLINK_BILLING_CA=/etc/ssl/certs/ca-certificates.crt
ENV SNAPLINK_STRIPE_ADAPTER_UPSTREAM=
ENV SNAPLINK_STRIPE_ADAPTER_SERVER_NAME=snaplink-stripe-adapter
ENV SNAPLINK_STRIPE_ADAPTER_CA=/etc/ssl/certs/ca-certificates.crt

# Copy Flutter build output
COPY --from=build /app/build/web /usr/share/nginx/html

# The official entrypoint renders environment variables in this template.
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.d/10-validate-upstreams.sh /docker-entrypoint.d/10-validate-upstreams.sh
RUN rm /etc/nginx/conf.d/default.conf
RUN chmod +x /docker-entrypoint.d/10-validate-upstreams.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
