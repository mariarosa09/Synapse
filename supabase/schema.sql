-- =====================================================================================
--  SYNAPSE – Supabase schema
--  Run this whole file once in the Supabase Dashboard → SQL Editor (it is idempotent:
--  running it again is safe).
--
--  Every table is owned by a user through `user_id` (or `id` for profiles), which defaults to
--  auth.uid(), and Row Level Security only lets a signed-in user see and change their own rows.
--  Files live in two PRIVATE storage buckets, inside a folder named after the user's id.
-- =====================================================================================

create extension if not exists pgcrypto;

-- -------------------------------------------------------------------------------------
-- Shared trigger: keep updated_at current
-- -------------------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =====================================================================================
-- PROFILES (one row per auth user)
-- =====================================================================================
create table if not exists public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  firstname            text not null default '' check (char_length(firstname) <= 100),
  middle_initial       text not null default '' check (char_length(middle_initial) <= 10),
  surname              text not null default '' check (char_length(surname) <= 100),
  email                text not null default '',
  avatar_path          text,
  sex                  text check (sex in ('Female', 'Male')),
  blood_group          text check (blood_group in ('A+','B+','AB+','O+','A-','B-','AB-','O-')),
  birthdate            date,
  onboarding_complete  boolean not null default false,
  deleted              boolean not null default false,
  deleted_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- The profile email always mirrors the authenticated email (clients cannot spoof it).
create or replace function public.profiles_force_auth_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select u.email into new.email from auth.users u where u.id = new.id;
  new.email := coalesce(new.email, '');
  return new;
end;
$$;

drop trigger if exists profiles_force_auth_email on public.profiles;
create trigger profiles_force_auth_email before insert or update on public.profiles
  for each row execute function public.profiles_force_auth_email();

-- =====================================================================================
-- GENERAL SETTINGS (one row per user; no appearance options)
-- =====================================================================================
create table if not exists public.user_settings (
  user_id                uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  notifications_enabled  boolean not null default true,
  medicine_reminders     boolean not null default true,
  appointment_reminders  boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- Older drafts of this schema had an appearance column; it is no longer used.
alter table public.user_settings drop column if exists appearance;

drop trigger if exists user_settings_updated_at on public.user_settings;
create trigger user_settings_updated_at before update on public.user_settings
  for each row execute function public.set_updated_at();

-- =====================================================================================
-- BASIC INFORMATION (allergies and medical conditions)
-- =====================================================================================
create table if not exists public.basic_information (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind        text not null check (kind in ('allergy', 'condition')),
  title       text not null check (char_length(title) between 1 and 200),
  start_date  date not null default current_date,
  end_date    date,
  active      boolean not null default true,
  notes       text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists basic_information_user_idx on public.basic_information (user_id, active, start_date desc);

drop trigger if exists basic_information_updated_at on public.basic_information;
create trigger basic_information_updated_at before update on public.basic_information
  for each row execute function public.set_updated_at();

-- =====================================================================================
-- MEDICINES
-- =====================================================================================
create table if not exists public.medicines (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  medication      text not null check (char_length(medication) between 1 and 200),
  amount          text not null default '',
  frequency       smallint not null default 1 check (frequency between 1 and 4),
  intake_minutes  integer[] not null default '{}'
                  check (cardinality(intake_minutes) <= 4
                         and 0 <= all (intake_minutes) and 1439 >= all (intake_minutes)),
  start_date      date not null default current_date,
  end_date        date not null default current_date,
  instructions    text not null default '',
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint medicines_dates_ok check (end_date >= start_date)
);
create index if not exists medicines_user_idx on public.medicines (user_id, active, medication);

drop trigger if exists medicines_updated_at on public.medicines;
create trigger medicines_updated_at before update on public.medicines
  for each row execute function public.set_updated_at();

-- =====================================================================================
-- APPOINTMENTS
-- =====================================================================================
create table if not exists public.appointments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  doctor      text not null default '',
  location    text not null default '',
  start_at    timestamptz not null,
  end_at      timestamptz not null,
  notes       text not null default '',
  status      text not null default 'scheduled' check (status in ('scheduled', 'completed', 'cancelled')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint appointments_times_ok check (end_at > start_at)
);
create index if not exists appointments_user_start_idx on public.appointments (user_id, start_at);

drop trigger if exists appointments_updated_at on public.appointments;
create trigger appointments_updated_at before update on public.appointments
  for each row execute function public.set_updated_at();

-- =====================================================================================
-- MEDICAL RECORDS + ATTACHMENTS
-- =====================================================================================
create table if not exists public.medical_records (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 200),
  record_date  date not null default current_date,
  category     text not null default '' check (char_length(category) <= 100),
  notes        text not null default '',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists medical_records_user_date_idx on public.medical_records (user_id, record_date desc);

drop trigger if exists medical_records_updated_at on public.medical_records;
create trigger medical_records_updated_at before update on public.medical_records
  for each row execute function public.set_updated_at();

create table if not exists public.medical_record_attachments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  record_id       uuid not null references public.medical_records (id) on delete cascade,
  file_name       text not null check (char_length(file_name) between 1 and 255),
  file_extension  text not null default '',
  mime_type       text not null default 'application/octet-stream',
  size_bytes      bigint not null default 0 check (size_bytes >= 0 and size_bytes <= 20971520),
  storage_path    text not null unique,
  created_at      timestamptz not null default now(),
  -- The file must sit in the owner's folder: "<user_id>/<record_id>/<file>"
  constraint attachment_path_ok check (storage_path like (user_id::text || '/' || record_id::text || '/%'))
);
create index if not exists medical_record_attachments_record_idx on public.medical_record_attachments (record_id);
create index if not exists medical_record_attachments_user_idx on public.medical_record_attachments (user_id);

-- An attachment can only point at a record owned by the same user.
create or replace function public.attachment_record_owner_check()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.medical_records r where r.id = new.record_id and r.user_id = new.user_id) then
    raise exception 'Attachment record does not belong to this user';
  end if;
  return new;
end;
$$;

drop trigger if exists attachment_record_owner_check on public.medical_record_attachments;
create trigger attachment_record_owner_check before insert or update on public.medical_record_attachments
  for each row execute function public.attachment_record_owner_check();

-- =====================================================================================
-- NEW USER: create the profile + settings rows from the sign-up metadata
-- (the client has no session until the email OTP is verified, so this runs server side)
-- =====================================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta       jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  full_name  text  := trim(coalesce(meta ->> 'full_name', meta ->> 'name', ''));
  first_name text;
  last_name  text;
begin
  -- Email sign-up sends firstname / surname; Google and Apple send full_name (or given / family name).
  first_name := coalesce(nullif(meta ->> 'firstname', ''), nullif(meta ->> 'given_name', ''),
                         split_part(full_name, ' ', 1));
  last_name  := coalesce(nullif(meta ->> 'surname', ''), nullif(meta ->> 'family_name', ''),
                         case when position(' ' in full_name) > 0
                              then trim(substr(full_name, position(' ' in full_name) + 1)) else '' end);

  insert into public.profiles (id, email, firstname, middle_initial, surname)
  values (
    new.id,
    coalesce(new.email, ''),
    left(coalesce(first_name, ''), 100),
    left(coalesce(meta ->> 'middle_initial', ''), 10),
    left(coalesce(last_name, ''), 100)
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep profiles.email in sync after an email change is confirmed with its OTP.
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = coalesce(new.email, '') where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- =====================================================================================
-- ROW LEVEL SECURITY
-- =====================================================================================
alter table public.profiles                    enable row level security;
alter table public.user_settings               enable row level security;
alter table public.basic_information           enable row level security;
alter table public.medicines                   enable row level security;
alter table public.appointments                enable row level security;
alter table public.medical_records             enable row level security;
alter table public.medical_record_attachments  enable row level security;

-- profiles: read / create / update your own row. Accounts are soft-deleted (flag), never removed by clients.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- user_settings
drop policy if exists "settings_select_own" on public.user_settings;
create policy "settings_select_own" on public.user_settings for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists "settings_insert_own" on public.user_settings;
create policy "settings_insert_own" on public.user_settings for insert to authenticated
  with check ((select auth.uid()) = user_id);
drop policy if exists "settings_update_own" on public.user_settings;
create policy "settings_update_own" on public.user_settings for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Owner-only CRUD for the per-user data tables.
do $$
declare
  t text;
begin
  foreach t in array array['basic_information', 'medicines', 'appointments', 'medical_records', 'medical_record_attachments']
  loop
    execute format('drop policy if exists "%1$s_select_own" on public.%1$I', t);
    execute format('create policy "%1$s_select_own" on public.%1$I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "%1$s_insert_own" on public.%1$I', t);
    execute format('create policy "%1$s_insert_own" on public.%1$I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "%1$s_update_own" on public.%1$I', t);
    execute format('create policy "%1$s_update_own" on public.%1$I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('drop policy if exists "%1$s_delete_own" on public.%1$I', t);
    execute format('create policy "%1$s_delete_own" on public.%1$I for delete to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end;
$$;

-- Anonymous visitors get nothing.
revoke all on public.profiles, public.user_settings, public.basic_information, public.medicines,
              public.appointments, public.medical_records, public.medical_record_attachments from anon;
grant select, insert, update, delete on public.basic_information, public.medicines, public.appointments,
              public.medical_records, public.medical_record_attachments to authenticated;
grant select, insert, update on public.profiles, public.user_settings to authenticated;

-- =====================================================================================
-- STORAGE: two private buckets, one folder per user
-- =====================================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('medical-records', 'medical-records', false, 20971520, null)   -- any type the app accepts, max 20 MB
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- A signed-in user may only read / write / delete objects inside "<their uid>/..." in these buckets.
drop policy if exists "synapse_storage_select_own" on storage.objects;
create policy "synapse_storage_select_own" on storage.objects for select to authenticated
  using (bucket_id in ('avatars', 'medical-records') and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "synapse_storage_insert_own" on storage.objects;
create policy "synapse_storage_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'medical-records') and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "synapse_storage_update_own" on storage.objects;
create policy "synapse_storage_update_own" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'medical-records') and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id in ('avatars', 'medical-records') and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "synapse_storage_delete_own" on storage.objects;
create policy "synapse_storage_delete_own" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'medical-records') and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================================
-- Backfill: profiles / settings for users that already existed before this script ran.
-- =====================================================================================
insert into public.profiles (id, email, firstname, middle_initial, surname)
select u.id, coalesce(u.email, ''),
       left(coalesce(u.raw_user_meta_data ->> 'firstname', ''), 100),
       left(coalesce(u.raw_user_meta_data ->> 'middle_initial', ''), 10),
       left(coalesce(u.raw_user_meta_data ->> 'surname', ''), 100)
from auth.users u
on conflict (id) do nothing;

insert into public.user_settings (user_id)
select u.id from auth.users u
on conflict (user_id) do nothing;

-- =====================================================================================
-- Hardening: fixed search_path, and trigger functions are not callable through the API.
-- (Triggers still run; EXECUTE is only checked when a trigger is created.)
-- =====================================================================================
alter function public.set_updated_at() set search_path = public;
alter function public.attachment_record_owner_check() set search_path = public;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_user_email_change() from public, anon, authenticated;
revoke execute on function public.profiles_force_auth_email() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.attachment_record_owner_check() from public, anon, authenticated;
