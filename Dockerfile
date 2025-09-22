# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:3.24.4 AS build

WORKDIR /app

COPY pubspec.yaml ./
COPY analysis_options.yaml ./
RUN flutter pub get

COPY . .

ARG EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
ARG EXPO_PUBLIC_SUPABASE_KEY=public-anon-key
RUN flutter build web --release \
  --dart-define=EXPO_PUBLIC_SUPABASE_URL=$EXPO_PUBLIC_SUPABASE_URL \
  --dart-define=EXPO_PUBLIC_SUPABASE_KEY=$EXPO_PUBLIC_SUPABASE_KEY

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
