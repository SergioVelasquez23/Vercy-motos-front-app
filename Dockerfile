# Compilación del frontend Flutter Web
FROM cirrusci/flutter:latest AS build
WORKDIR /app
COPY . .
RUN flutter build web

# Servir con NGINX
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
