# flutter_my_park

Docker-first Flutter + Supabase example. The app authenticates with email/password or Google/Facebook entirely inside containers.

## Prerequisites

- Docker Desktop or the Docker Engine with Compose plugin
- A Supabase project with the email/password provider enabled
- Optional: Google and Facebook providers enabled with redirect URLs set to `http://localhost:8080/`

## Supabase configuration

Export your Supabase project URL and anon key so the build can inject them at compile time:

```
setx EXPO_PUBLIC_SUPABASE_URL https://your-project.supabase.co
setx EXPO_PUBLIC_SUPABASE_KEY your-anon-key
```

Or create a `.env` file in the project root:

```
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_KEY=your-anon-key
```

For social login, ensure Supabase has the Google and/or Facebook providers enabled and that the redirect URLs include `http://localhost:8080/` (or your deployed domain).

If the variables are omitted, placeholder values are used and authentication requests will fail.

## Run the app

1. Build the image (caches dependencies and injects Supabase config):
   ```
   docker compose build
   ```
2. Start the container and keep it attached:
   ```
   docker compose up
   ```
3. Open http://localhost:8080 in a browser.

Stop with `Ctrl+C` and clean up with `docker compose down`.

## Iterate on the UI

- Edit Flutter sources under `lib/`.
- Rebuild to pull in code changes and any updated environment variables:
  ```
  docker compose build
  ```
- Relaunch with `docker compose up`.

## How it works

- `Supabase.initialize` runs before `runApp`, using `--dart-define` values compiled into the web bundle.
- Auth state changes decide between the login/register tabs and the home screen that shows the signed-in email and a logout button.
- Google and Facebook buttons call `signInWithOAuth`, which hands control back to the same origin after Supabase finishes the flow.
- The multi-stage Docker build compiles the Flutter web app in the Cirrus Labs Flutter image, then serves the static assets from Nginx on port 8080.
- `.dockerignore` keeps transient Flutter build output out of the Docker context for faster rebuilds.
