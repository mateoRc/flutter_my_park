# flutter_my_park

Docker-first Flutter + Supabase example. The app authenticates with email/password or Google/Facebook entirely inside containers.

## MVP Plan Status
- [ ] Run Supabase SQL for geospatial schema, security policies, storage bucket, and booking RPC
- [ ] Seed Supabase with demo host/guest data
- [x] Define Dart domain models for profiles, spots, photos, bookings, and favorites
- [x] Implement Supabase repositories with geospatial search and booking RPC integration
- [ ] Wire dependency injection and routing
- [ ] Build host spot create/edit flow with photo uploads
- [ ] Implement guest map search and spot detail experience
- [ ] Complete booking UI flow, listings, and final polish

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

### Google quick checklist

1. **Google Cloud Console > APIs & Services > Credentials > OAuth client (Web)**
   - Authorized JavaScript origins: `http://localhost:8080`, `https://your-project.supabase.co`
   - Authorized redirect URIs: `http://localhost:8080/`, `https://your-project.supabase.co/auth/v1/callback`
2. **Supabase > Authentication > Providers > Google**
   - Paste the Google client ID and secret
   - Enable the provider
3. Rebuild the app: `docker compose build && docker compose up`

## Supabase SQL setup

Run the following statements in the Supabase SQL editor (adjust bucket/table names or UUIDs as needed).

### 1. Geospatial schema, indexes, and policies

```sql
-- Extensions
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- Profiles
default
create table if not exists profiles (
  id uuid primary key default auth.uid(),
  name text,
  phone text,
  created_at timestamptz not null default now()
);

-- Spots
create table if not exists spots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  title text not null,
  lat double precision not null,
  lng double precision not null,
  address text,
  price_hour numeric(10,2),
  price_day numeric(10,2),
  amenities text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table spots add column if not exists geom geography(point);

-- Spot photos
create table if not exists spot_photos (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references spots(id) on delete cascade,
  path text not null,
  "order" integer not null,
  created_at timestamptz not null default now()
);

-- Bookings
create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references spots(id) on delete cascade,
  guest_id uuid not null,
  start_ts timestamptz not null,
  end_ts timestamptz not null,
  price_total numeric(10,2),
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

-- Favorites
create table if not exists favorites (
  user_id uuid not null,
  spot_id uuid not null references spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- Keep geom in sync
create or replace function set_spot_geom()
returns trigger
language plpgsql as $$
begin
  if new.lat is not null and new.lng is not null then
    new.geom := geography(ST_SetSRID(ST_MakePoint(new.lng, new.lat), 4326));
  else
    new.geom := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_spots_set_geom on spots;
create trigger trg_spots_set_geom
before insert or update of lat, lng on spots
for each row execute function set_spot_geom();

-- Backfill geom for existing rows
update spots
set geom = geography(ST_SetSRID(ST_MakePoint(lng, lat), 4326))
where geom is null;

-- Indexes
create index if not exists idx_spots_geom_gist on spots using gist (geom);
create index if not exists idx_spots_owner_id on spots (owner_id);
create index if not exists idx_spot_photos_spot_id on spot_photos (spot_id);
create index if not exists idx_bookings_spot_id on bookings (spot_id);
create index if not exists idx_bookings_guest_id on bookings (guest_id);
create index if not exists idx_bookings_status on bookings (status);

-- Unique order per spot photo
alter table spot_photos
  add constraint spot_photos_spot_order_unique unique (spot_id, "order");

-- Enable RLS
alter table profiles enable row level security;
alter table spots enable row level security;
alter table spot_photos enable row level security;
alter table bookings enable row level security;
alter table favorites enable row level security;

-- Profiles policies
drop policy if exists profiles_select_self on profiles;
create policy profiles_select_self
  on profiles for select
  using (id = auth.uid());

drop policy if exists profiles_upsert_self on profiles;
create policy profiles_upsert_self
  on profiles for insert
  with check (id = auth.uid());

drop policy if exists profiles_update_self on profiles;
create policy profiles_update_self
  on profiles for update
  using (id = auth.uid());

-- Spots policies
drop policy if exists spots_public_select on spots;
create policy spots_public_select
  on spots for select using (true);

drop policy if exists spots_owner_insert on spots;
create policy spots_owner_insert
  on spots for insert
  with check (owner_id = auth.uid());

drop policy if exists spots_owner_update on spots;
create policy spots_owner_update
  on spots for update
  using (owner_id = auth.uid());

drop policy if exists spots_owner_delete on spots;
create policy spots_owner_delete
  on spots for delete
  using (owner_id = auth.uid());

-- Spot photos policies
drop policy if exists spot_photos_public_select on spot_photos;
create policy spot_photos_public_select
  on spot_photos for select using (true);

drop policy if exists spot_photos_owner_write on spot_photos;
create policy spot_photos_owner_write
  on spot_photos for all
  using (
    exists (
      select 1 from spots
      where spots.id = spot_photos.spot_id
        and spots.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from spots
      where spots.id = spot_photos.spot_id
        and spots.owner_id = auth.uid()
    )
  );

-- Bookings policies
drop policy if exists bookings_guest_crud on bookings;
create policy bookings_guest_crud
  on bookings
  for all
  using (guest_id = auth.uid())
  with check (guest_id = auth.uid());

drop policy if exists bookings_host_select on bookings;
create policy bookings_host_select
  on bookings for select using (
    exists (
      select 1 from spots
      where spots.id = bookings.spot_id
        and spots.owner_id = auth.uid()
    )
  );

-- Favorites policies
drop policy if exists favorites_crud_self on favorites;
create policy favorites_crud_self
  on favorites
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

### 2. Storage bucket policies

```sql
select storage.create_bucket('spot-photos', public => true)
where not exists (
  select 1 from storage.buckets where id = 'spot-photos'
);

-- Public read
drop policy if exists spot_photos_public_read on storage.objects;
create policy spot_photos_public_read
  on storage.objects for select
  using (bucket_id = 'spot-photos');

-- Authenticated uploads (first path segment must be spot UUID owned by user)
drop policy if exists spot_photos_owner_insert on storage.objects;
create policy spot_photos_owner_insert
  on storage.objects for insert
  with check (
    bucket_id = 'spot-photos'
    and auth.role() = 'authenticated'
    and position('/' in name) > 0
    and exists (
      select 1 from spots
      where spots.id = split_part(name, '/', 1)::uuid
        and spots.owner_id = auth.uid()
    )
  );

-- Owner deletes
drop policy if exists spot_photos_owner_delete on storage.objects;
create policy spot_photos_owner_delete
  on storage.objects for delete
  using (
    bucket_id = 'spot-photos'
    and auth.role() = 'authenticated'
    and exists (
      select 1 from spots
      where spots.id = split_part(name, '/', 1)::uuid
        and spots.owner_id = auth.uid()
    )
  );
```

### 3. Booking RPC

```sql
create or replace function create_booking(
  p_spot uuid,
  p_start timestamptz,
  p_end timestamptz
) returns bookings
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_price_per_hour numeric;
  v_hours numeric;
  v_total numeric;
  v_booking bookings;
begin
  if p_end <= p_start then
    raise exception 'end must be after start';
  end if;

  select price_hour into v_price_per_hour from spots where id = p_spot;
  if v_price_per_hour is null then
    raise exception 'spot not found or missing price';
  end if;

  if exists (
    select 1 from bookings
    where spot_id = p_spot
      and tstzrange(start_ts, end_ts, '[)') && tstzrange(p_start, p_end, '[)')
  ) then
    raise exception 'booking overlaps existing reservation';
  end if;

  v_hours := ceil(extract(epoch from (p_end - p_start)) / 3600);
  v_total := v_hours * v_price_per_hour;

  insert into bookings (spot_id, guest_id, start_ts, end_ts, price_total, status)
  values (p_spot, auth.uid(), p_start, p_end, v_total, 'confirmed')
  returning * into v_booking;

  return v_booking;
end;
$$;

revoke all on function create_booking from public;
grant execute on function create_booking(uuid, timestamptz, timestamptz) to authenticated;
```

### 4. Seed sample data

Replace the placeholder UUIDs with real values from your project before running.

```sql
-- Replace with actual auth.users UUIDs
insert into profiles (id, name, phone)
values
  ('{HOST_UUID}', 'Host User', '+385-91-000-0000')
on conflict (id) do update set name = excluded.name, phone = excluded.phone;

insert into profiles (id, name, phone)
values
  ('{GUEST_UUID}', 'Guest User', '+385-91-111-1111')
on conflict (id) do update set name = excluded.name, phone = excluded.phone;

insert into spots (id, owner_id, title, lat, lng, address, price_hour, price_day, amenities)
values
  (gen_random_uuid(), '{HOST_UUID}', 'Central Garage', 45.8150, 15.9819, 'Main Square 1, Zagreb', 5.0, 25.0, '{covered,secured}'),
  (gen_random_uuid(), '{HOST_UUID}', 'Riverside Parking', 45.8040, 15.9730, 'Savska cesta 15, Zagreb', 4.0, 20.0, '{outdoor,lighting}'),
  (gen_random_uuid(), '{HOST_UUID}', 'Old Town Spot', 45.8165, 15.9785, 'Tkalciceva 12, Zagreb', 6.0, 30.0, '{covered,charger}')
on conflict do nothing;

-- Example photo entries (update spot_id/path per row)
-- insert into spot_photos (spot_id, path, "order") values ('{SPOT_UUID}', 'spots/{SPOT_UUID}/photo1.webp', 1);

-- Example bookings for the guest
insert into bookings (spot_id, guest_id, start_ts, end_ts, price_total, status)
select id, '{GUEST_UUID}', '2025-05-04T08:00:00Z', '2025-05-04T10:00:00Z', 10.0, 'confirmed'
from spots
limit 1
on conflict do nothing;
```

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

## Test the app

Run Flutter tests inside Docker using the CLI service:

```
docker compose run --rm flutter_cli "flutter pub get && flutter test"
```

## How it works

- `Supabase.initialize` runs before `runApp`, using `--dart-define` values compiled into the web bundle.
- Auth state changes decide between the login/register tabs and the home screen that shows the signed-in email and a logout button.
- The nearby search demo calls the PostGIS-backed `spots_nearby` RPC.
- Bookings go through the `create_booking` RPC, which enforces overlap rules and pricing.
- The multi-stage Docker build compiles the Flutter web app in the Cirrus Labs Flutter image, then serves the static assets from Nginx on port 8080.
- `.dockerignore` keeps transient Flutter build output out of the Docker context for faster rebuilds.
