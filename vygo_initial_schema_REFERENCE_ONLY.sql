-- VYGO | Initial Supabase schema
-- Project: jlp... (use only in the Supabase project shown by the owner)
-- Run this entire file once in Supabase Dashboard > SQL Editor > New query.
-- This migration is designed for a fresh VYGO project.

begin;

create extension if not exists pgcrypto;

do $$ begin
  create type public.vygo_user_role as enum ('passenger', 'driver', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.vygo_trip_status as enum
    ('requested', 'negotiating', 'accepted', 'driver_arriving', 'in_progress', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.vygo_offer_status as enum ('pending', 'accepted', 'rejected', 'withdrawn');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text unique,
  avatar_url text,
  role public.vygo_user_role not null default 'passenger',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.driver_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  document_type text,
  document_number text,
  license_number text,
  license_expiry date,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','approved','rejected')),
  is_available boolean not null default false,
  rating numeric(3,2) not null default 5.00 check (rating between 0 and 5),
  total_trips integer not null default 0 check (total_trips >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(user_id) on delete cascade,
  make text not null,
  model text not null,
  year integer check (year between 1980 and 2100),
  color text,
  plate text not null unique,
  vehicle_type text not null default 'car',
  capacity integer not null default 4 check (capacity between 1 and 50),
  has_trunk boolean not null default true,
  photo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  passenger_id uuid not null references public.profiles(id),
  driver_id uuid references public.profiles(id),
  vehicle_id uuid references public.vehicles(id),
  pickup_address text not null,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_address text not null,
  destination_lat double precision,
  destination_lng double precision,
  distance_meters integer check (distance_meters is null or distance_meters >= 0),
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  passenger_note text,
  requested_fare numeric(12,2) check (requested_fare is null or requested_fare >= 0),
  agreed_fare numeric(12,2) check (agreed_fare is null or agreed_fare >= 0),
  currency text not null default 'COP',
  status public.vygo_trip_status not null default 'requested',
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists trips_passenger_created_idx on public.trips(passenger_id, created_at desc);
create index if not exists trips_driver_created_idx on public.trips(driver_id, created_at desc);
create index if not exists trips_status_created_idx on public.trips(status, created_at desc);

create table if not exists public.trip_offers (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  driver_id uuid not null references public.profiles(id),
  fare numeric(12,2) not null check (fare > 0),
  message text,
  status public.vygo_offer_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (trip_id, driver_id, created_at)
);

create index if not exists trip_offers_trip_created_idx on public.trip_offers(trip_id, created_at desc);

create table if not exists public.trip_events (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists trip_events_trip_created_idx on public.trip_events(trip_id, created_at);

create table if not exists public.driver_locations (
  driver_id uuid primary key references public.driver_profiles(user_id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  heading double precision,
  speed_mps double precision,
  recorded_at timestamptz not null default now()
);

create table if not exists public.trip_ratings (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id),
  reviewee_id uuid not null references public.profiles(id),
  score integer not null check (score between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (trip_id, reviewer_id)
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid references public.profiles(id),
  action text not null,
  target_table text,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- updated_at helper
create or replace function public.vygo_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- New auth users get a passenger profile by default.
-- A user may request driver role at signup; admin is never accepted from metadata.
create or replace function public.vygo_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'passenger');
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    case when requested_role = 'driver'
      then 'driver'::public.vygo_user_role
      else 'passenger'::public.vygo_user_role
    end
  )
  on conflict (id) do nothing;

  if requested_role = 'driver' then
    insert into public.driver_profiles (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists vygo_on_auth_user_created on auth.users;
create trigger vygo_on_auth_user_created
after insert on auth.users
for each row execute procedure public.vygo_handle_new_user();

-- Security-definer helpers avoid recursive RLS policy checks.
create or replace function public.vygo_is_admin()
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'::public.vygo_user_role
  );
$$;

create or replace function public.vygo_is_trip_member(p_trip_id uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.trips t
    where t.id = p_trip_id
      and ((select auth.uid()) = t.passenger_id or (select auth.uid()) = t.driver_id)
  );
$$;

-- Enable row-level security on every exposed table.
alter table public.profiles enable row level security;
alter table public.driver_profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_offers enable row level security;
alter table public.trip_events enable row level security;
alter table public.driver_locations enable row level security;
alter table public.trip_ratings enable row level security;
alter table public.admin_audit_log enable row level security;

-- Profiles: users can see/update their own profile; admins can manage all.
drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
for update to authenticated
using (id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (
  (id = (select auth.uid()) and role <> 'admin'::public.vygo_user_role)
  or (select public.vygo_is_admin())
);

-- Drivers: driver owns their record; admins manage; approved drivers are visible to signed-in users.
drop policy if exists "driver_profiles_select" on public.driver_profiles;
create policy "driver_profiles_select" on public.driver_profiles
for select to authenticated
using (
  user_id = (select auth.uid())
  or verification_status = 'approved'
  or (select public.vygo_is_admin())
);

drop policy if exists "driver_profiles_insert_self" on public.driver_profiles;
create policy "driver_profiles_insert_self" on public.driver_profiles
for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "driver_profiles_update_self_or_admin" on public.driver_profiles;
create policy "driver_profiles_update_self_or_admin" on public.driver_profiles
for update to authenticated
using (user_id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (user_id = (select auth.uid()) or (select public.vygo_is_admin()));

-- Vehicles: public to authenticated users only when active; owner/admin can manage.
drop policy if exists "vehicles_select" on public.vehicles;
create policy "vehicles_select" on public.vehicles
for select to authenticated
using ((is_active and exists (
  select 1 from public.driver_profiles d
  where d.user_id = driver_id and d.verification_status = 'approved'
)) or driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "vehicles_insert_owner" on public.vehicles;
create policy "vehicles_insert_owner" on public.vehicles
for insert to authenticated
with check (driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "vehicles_update_owner" on public.vehicles;
create policy "vehicles_update_owner" on public.vehicles
for update to authenticated
using (driver_id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "vehicles_delete_owner" on public.vehicles;
create policy "vehicles_delete_owner" on public.vehicles
for delete to authenticated
using (driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

-- Trips: passenger creates; only trip members/admin read; participants/admin update.
drop policy if exists "trips_insert_passenger" on public.trips;
create policy "trips_insert_passenger" on public.trips
for insert to authenticated
with check (passenger_id = (select auth.uid()) and driver_id is null);

drop policy if exists "trips_select_members_admin" on public.trips;
create policy "trips_select_members_admin" on public.trips
for select to authenticated
using (passenger_id = (select auth.uid()) or driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "trips_update_members_admin" on public.trips;
create policy "trips_update_members_admin" on public.trips
for update to authenticated
using (passenger_id = (select auth.uid()) or driver_id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (passenger_id = (select auth.uid()) or driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

-- Offers: verified drivers may offer; trip participants/admin can read; offer owner/admin can edit.
drop policy if exists "trip_offers_select_members" on public.trip_offers;
create policy "trip_offers_select_members" on public.trip_offers
for select to authenticated
using (
  driver_id = (select auth.uid())
  or (select public.vygo_is_trip_member(trip_id))
  or (select public.vygo_is_admin())
);

drop policy if exists "trip_offers_insert_driver" on public.trip_offers;
create policy "trip_offers_insert_driver" on public.trip_offers
for insert to authenticated
with check (
  driver_id = (select auth.uid())
  and exists (
    select 1 from public.driver_profiles d
    where d.user_id = (select auth.uid())
      and d.verification_status = 'approved'
  )
  and exists (
    select 1 from public.trips t
    where t.id = trip_id and t.status in ('requested','negotiating')
      and t.passenger_id <> (select auth.uid())
  )
);

drop policy if exists "trip_offers_update_owner_or_admin" on public.trip_offers;
create policy "trip_offers_update_owner_or_admin" on public.trip_offers
for update to authenticated
using (driver_id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

-- Trip events and ratings.
drop policy if exists "trip_events_select_members" on public.trip_events;
create policy "trip_events_select_members" on public.trip_events
for select to authenticated
using ((select public.vygo_is_trip_member(trip_id)) or (select public.vygo_is_admin()));

drop policy if exists "trip_events_insert_members" on public.trip_events;
create policy "trip_events_insert_members" on public.trip_events
for insert to authenticated
with check (
  actor_id = (select auth.uid())
  and ((select public.vygo_is_trip_member(trip_id)) or (select public.vygo_is_admin()))
);

drop policy if exists "driver_locations_select" on public.driver_locations;
create policy "driver_locations_select" on public.driver_locations
for select to authenticated
using (
  driver_id = (select auth.uid())
  or (select public.vygo_is_admin())
  or exists (
    select 1 from public.trips t
    where t.driver_id = driver_id
      and t.passenger_id = (select auth.uid())
      and t.status in ('accepted','driver_arriving','in_progress')
  )
);

drop policy if exists "driver_locations_upsert_self" on public.driver_locations;
create policy "driver_locations_upsert_self" on public.driver_locations
for all to authenticated
using (driver_id = (select auth.uid()) or (select public.vygo_is_admin()))
with check (driver_id = (select auth.uid()) or (select public.vygo_is_admin()));

drop policy if exists "trip_ratings_select_members" on public.trip_ratings;
create policy "trip_ratings_select_members" on public.trip_ratings
for select to authenticated
using (
  reviewer_id = (select auth.uid())
  or reviewee_id = (select auth.uid())
  or (select public.vygo_is_admin())
);

drop policy if exists "trip_ratings_insert_completed_member" on public.trip_ratings;
create policy "trip_ratings_insert_completed_member" on public.trip_ratings
for insert to authenticated
with check (
  reviewer_id = (select auth.uid())
  and exists (
    select 1 from public.trips t
    where t.id = trip_id and t.status = 'completed'
      and ((t.passenger_id = (select auth.uid()) and t.driver_id = reviewee_id)
        or (t.driver_id = (select auth.uid()) and t.passenger_id = reviewee_id))
  )
);

-- Admin audit log: admin-only.
drop policy if exists "admin_audit_admin_only" on public.admin_audit_log;
create policy "admin_audit_admin_only" on public.admin_audit_log
for all to authenticated
using ((select public.vygo_is_admin()))
with check ((select public.vygo_is_admin()));

-- updated_at triggers
do $$ declare tbl text; begin
  foreach tbl in array array['profiles','driver_profiles','trips','trip_offers'] loop
    execute format('drop trigger if exists %I on public.%I', 'set_updated_at_' || tbl, tbl);
    execute format('create trigger %I before update on public.%I for each row execute procedure public.vygo_set_updated_at()', 'set_updated_at_' || tbl, tbl);
  end loop;
end $$;

-- Grant only normal application access. RLS remains the security boundary.
grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.driver_profiles to authenticated;
grant select, insert, update, delete on public.vehicles to authenticated;
grant select, insert, update on public.trips to authenticated;
grant select, insert, update on public.trip_offers to authenticated;
grant select, insert on public.trip_events to authenticated;
grant select, insert, update on public.driver_locations to authenticated;
grant select, insert on public.trip_ratings to authenticated;
grant select, insert on public.admin_audit_log to authenticated;
grant usage, select on sequence public.admin_audit_log_id_seq to authenticated;

commit;

-- IMPORTANT ADMIN SETUP:
-- After you create your own account through Supabase Auth, run this separately,
-- replacing the email with the exact email used for your account:
-- update public.profiles p
-- set role = 'admin'
-- from auth.users u
-- where p.id = u.id and u.email = 'TU_CORREO@EJEMPLO.COM';
--
-- Never put the Supabase service_role key in the Flutter app or in GitHub.
-- Use the project URL and anon/publishable key in the client only.
