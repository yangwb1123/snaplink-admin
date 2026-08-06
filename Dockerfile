FROM python:3.12-slim AS build

ARG FLUTTER_VERSION=3.38.8
ARG SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api

WORKDIR /app

# Install Flutter SDK dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.gz \
    | tar xz -C /opt \
    && /opt/flutter/bin/flutter config --enable-web \
    && /opt/flutter/bin/flutter precache --web

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Build the Flutter app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --base-href=/app/ \
    --dart-define=SNAPLINK_ADMIN_OAUTH_RESOURCES="${SNAPLINK_ADMIN_OAUTH_RESOURCES}"

# ── Production stage ──
FROM nginx:alpine

ENV SNAPLINK_UPSTREAM=http://snaplink:8080
ENV SNAPLINK_SERVER_NAME=snaplink
ENV SNAPLINK_CA=/etc/ssl/certs/ca-certificates.crt
ENV SNAPLINK_BILLING_UPSTREAM=http://snaplink:8080
ENV SNAPLINK_BILLING_SERVER_NAME=snaplink-billing
ENV SNAPLINK_BILLING_CA=/etc/ssl/certs/ca-certificates.crt
ENV SNAPLINK_STRIPE_ADAPTER_UPSTREAM=http://snaplink:8080
ENV SNAPLINK_STRIPE_ADAPTER_SERVER_NAME=snaplink-stripe-adapter
ENV SNAPLINK_STRIPE_ADAPTER_CA=/etc/ssl/certs/ca-certificates.crt

# Copy Flutter build output
COPY --from=build /app/build/web /usr/share/nginx/html

# The official entrypoint renders environment variables in this template.
COPY nginx.conf /etc/nginx/templates/default.conf.template
RUN rm /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
