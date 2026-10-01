
create schema if not exists private;
grant usage on schema private to anon, authenticated;

-- ENUMS
create type public.workspace_role        as enum ('admin','member');
create type public.member_type           as enum ('internal','referral');
create type public.member_status         as enum ('invited','active','disabled');
create type public.verification_status   as enum ('unverified','pending','verified','rejected');
create type public.opportunity_source    as enum ('public_form','internal_form','referral');
create type public.opportunity_visibility as enum ('public','private');
create type public.dispatch_priority     as enum ('emergency','scheduled');
create type public.opportunity_status    as enum ('new','offered','accepted','cancelled','expired');
create type public.offer_status          as enum ('pending','accepted','declined','expired','withdrawn');
create type public.project_status        as enum ('accepted','en_route','in_progress','inspection','completed','cancelled');
create type public.billing_type          as enum ('insurance','self_pay','direct_commercial','hold');
create type public.participant_role      as enum ('assignee','crew','referral');
create type public.referral_target       as enum ('individual','workspace');
create type public.referral_status       as enum ('draft','link_sent','viewed','accepted','in_progress','finished','revoked','expired');
create type public.payout_status         as enum ('pending','held','released','paid','cancelled');

create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

-- PEOPLE
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  email             text,
  full_name         text,
  phone             text,
  avatar_url        text,
  is_platform_admin boolean not null default false,
  stripe_account_id text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create unique index profiles_email_key on public.profiles (lower(email)) where email is not null;

-- WORKSPACES
create table public.workspaces (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null check (length(trim(name)) > 0),
  slug                  text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  logo_url              text,
  public_key            text not null unique default replace(gen_random_uuid()::text, '-', ''),
  timezone              text not null default 'America/Chicago',
  tier_timeout_minutes  int  not null default 15 check (tier_timeout_minutes > 0),
  is_active             boolean not null default true,
  created_by            uuid references public.profiles(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- SERVICE CATALOG (global, managed by platform admin)
create table public.services (
  id                    uuid primary key default gen_random_uuid(),
  code                  text not null unique check (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name                  text not null unique,
  description           text,
  tag                   text,
  response_label        text,
  is_bookable           boolean not null default false,
  requires_verification boolean not null default false,
  is_active             boolean not null default true,
  sort_order            int not null default 0,
  created_at            timestamptz not null default now()
);

-- MEMBERSHIP: internal team + referral accounts both live here
create table public.workspace_members (
  workspace_id             uuid not null references public.workspaces(id) on delete cascade,
  user_id                  uuid not null references public.profiles(id) on delete cascade,
  member_type              public.member_type   not null default 'internal',
  role                     public.workspace_role not null default 'member',
  status                   public.member_status not null default 'active',
  job_title                text,
  commission_pct           numeric(5,2) check (commission_pct between 0 and 100),
  referred_by              uuid references public.profiles(id) on delete set null,
  available_for_scheduling boolean not null default true,
  allowed_to_schedule      boolean not null default false,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  primary key (workspace_id, user_id),
  constraint referral_members_are_not_admins check (member_type = 'internal' or role = 'member')
);
create index workspace_members_user_idx on public.workspace_members (user_id);
create index workspace_members_referred_by_idx on public.workspace_members (referred_by) where referred_by is not null;

create table public.workspace_services (          -- "Core Services" screen
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  service_id   uuid not null references public.services(id)   on delete cascade,
  primary key (workspace_id, service_id)
);
create index workspace_services_service_idx on public.workspace_services (service_id);

create table public.workspace_locations (         -- "Location" screen
  id                   uuid primary key default gen_random_uuid(),
  workspace_id         uuid not null references public.workspaces(id) on delete cascade,
  name                 text not null,
  latitude             numeric(9,6),
  longitude            numeric(9,6),
  service_radius_miles numeric(6,1) check (service_radius_miles >= 0),
  postal_codes         text[] not null default '{}',
  created_at           timestamptz not null default now()
);
create index workspace_locations_ws_idx  on public.workspace_locations (workspace_id);
create index workspace_locations_zip_idx on public.workspace_locations using gin (postal_codes);

create table public.member_services (             -- "User Tiers" screen: tier per member per service
  workspace_id        uuid not null,
  user_id             uuid not null,
  service_id          uuid not null references public.services(id) on delete cascade,
  tier                smallint not null default 1 check (tier between 1 and 3),
  verification_status public.verification_status not null default 'unverified',
  created_at          timestamptz not null default now(),
  primary key (workspace_id, user_id, service_id),
  foreign key (workspace_id, user_id) references public.workspace_members(workspace_id, user_id) on delete cascade
);
create index member_services_service_idx on public.member_services (service_id);

create table public.member_availability (
  workspace_id          uuid not null,
  user_id               uuid not null,
  day_of_week           smallint not null check (day_of_week between 0 and 6),
  available_9_5         boolean not null default false,
  available_after_hours boolean not null default false,
  primary key (workspace_id, user_id, day_of_week),
  foreign key (workspace_id, user_id) references public.workspace_members(workspace_id, user_id) on delete cascade
);

