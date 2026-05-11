FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG GATEWAY_URL=http://localhost:9090

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter build web --release --dart-define=GATEWAY_URL=${GATEWAY_URL}

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
