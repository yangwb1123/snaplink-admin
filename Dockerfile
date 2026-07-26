FROM python:3.12-slim AS build

WORKDIR /app

# Install Flutter SDK dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_VERSION=3.38.8
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.gz \
    | tar xz -C /opt \
    && /opt/flutter/bin/flutter config --enable-web \
    && /opt/flutter/bin/flutter precache --web

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Build the Flutter app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# ── Production stage ──
FROM nginx:alpine

# Copy Flutter build output
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx config for SPA routing
RUN echo 'server { \
    listen 4444; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://snaplink:8080; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
    } \
    location /auth/ { \
        proxy_pass http://snaplink:8080; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 4444

CMD ["nginx", "-g", "daemon off;"]
