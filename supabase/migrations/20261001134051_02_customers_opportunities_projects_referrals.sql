
-- CUSTOMERS (people who book; belong to the workspace whose form/dashboard captured them)
create table public.customers (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  full_name    text not null check (length(trim(full_name)) > 0),
  phone        text,
  email        text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint customers_has_contact check (email is not null or phone is not null)
);
create unique index customers_ws_email_key on public.customers (workspace_id, lower(email)) where email is not null;
create index customers_ws_idx on public.customers (workspace_id);

-- OPPORTUNITIES = the booking form submission (public form OR internal form)
create table public.opportunities (
  id                    uuid primary key default gen_random_uuid(),
  workspace_id          uuid not null references public.workspaces(id) on delete cascade,  -- workspace that received it
  customer_id           uuid not null references public.customers(id) on delete restrict,
  service_id            uuid not null references public.services(id),
  source                public.opportunity_source     not null,
  visibility            public.opportunity_visibility not null default 'public',
  priority              public.dispatch_priority      not null default 'emergency',
  status                public.opportunity_status     not null default 'new',
  postal_code           text not null check (length(trim(postal_code)) between 3 and 10),
  address               text,
  city                  text,
  state                 text,
  latitude              numeric(9,6),
  longitude             numeric(9,6),
  damage_notes          text check (length(damage_notes) <= 4000),
  preferred_date        date,
  preferred_window      text check (preferred_window in ('08:00-12:00','12:00-16:00','16:00-20:00')),
  notify_before_hours   smallint not null default 2 check (notify_before_hours between 0 and 48),
  created_by            uuid references public.profiles(id) on delete set null,   -- null = anonymous public form
  accepted_by           uuid references public.profiles(id) on delete set null,
  accepted_workspace_id uuid references public.workspaces(id) on delete set null,
  accepted_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint scheduled_needs_date check (priority = 'emergency' or (preferred_date is not null and preferred_window is not null)),
  constraint internal_form_has_creator check (source = 'public_form' or created_by is not null),
  constraint accepted_fields_together check ((status = 'accepted') = (accepted_by is not null and accepted_workspace_id is not null and accepted_at is not null))
);
create index opportunities_ws_status_idx   on public.opportunities (workspace_id, status, created_at desc);
create index opportunities_board_idx       on public.opportunities (service_id, postal_code) where status in ('new','offered') and visibility = 'public';
create index opportunities_customer_idx    on public.opportunities (customer_id);
create index opportunities_accepted_ws_idx on public.opportunities (accepted_workspace_id) where accepted_workspace_id is not null;
create index opportunities_created_by_idx  on public.opportunities (created_by) where created_by is not null;

-- one-time upload tokens so anonymous visitors can attach photos (never exposed through the API)
create table private.upload_tokens (
  opportunity_id uuid primary key references public.opportunities(id) on delete cascade,
  token          text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  expires_at     timestamptz not null default now() + interval '1 hour'
);

create table public.opportunity_media (
  id             uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  storage_path   text not null unique,
  file_name      text,
  mime_type      text not null check (mime_type in ('image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime')),
  size_bytes     bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  created_at     timestamptz not null default now()
);
create index opportunity_media_opp_idx on public.opportunity_media (opportunity_id);

create or replace function private.limit_media_per_opportunity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.opportunity_media where opportunity_id = new.opportunity_id) >= 5 then
    raise exception 'A maximum of 5 files is allowed per request' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger opportunity_media_limit before insert on public.opportunity_media
  for each row execute function private.limit_media_per_opportunity();

-- OFFERS = routing by tier ("User Tiers"): who was offered which opportunity
create table public.opportunity_offers (
  id             uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  workspace_id   uuid not null references public.workspaces(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  tier           smallint not null check (tier between 1 and 3),
  status         public.offer_status not null default 'pending',
  offered_at     timestamptz not null default now(),
  expires_at     timestamptz not null,
  responded_at   timestamptz,
  unique (opportunity_id, user_id)
);
create index opportunity_offers_user_idx on public.opportunity_offers (user_id, status);
create index opportunity_offers_ws_idx   on public.opportunity_offers (workspace_id);
create index opportunity_offers_pending_idx on public.opportunity_offers (expires_at) where status = 'pending';

-- PROJECTS = an accepted opportunity ("My Projects")
create table public.projects (
  id               uuid primary key default gen_random_uuid(),
  opportunity_id   uuid not null unique references public.opportunities(id) on delete restrict,
  workspace_id     uuid not null references public.workspaces(id) on delete restrict,   -- workspace that owns the job
  customer_id      uuid not null references public.customers(id) on delete restrict,
  service_id       uuid not null references public.services(id),
  assigned_to      uuid references public.profiles(id) on delete set null,
  status           public.project_status not null default 'accepted',
  billing_type     public.billing_type,
  scope_estimate   numeric(12,2) check (scope_estimate >= 0),
  scheduled_start  timestamptz,
  completed_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index projects_ws_status_idx on public.projects (workspace_id, status);
create index projects_assigned_idx  on public.projects (assigned_to) where assigned_to is not null;
create index projects_customer_idx  on public.projects (customer_id);
create index projects_service_idx   on public.projects (service_id);

-- who can see/work a project (assignee, crew, referral) -> this is what limits referral access
create table public.project_members (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.participant_role not null,
  added_by   uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);
create index project_members_user_idx on public.project_members (user_id);

-- REFERRAL INVITES = "Quick Referral" + the unique secure link
create table public.referral_invites (
  id                   uuid primary key default gen_random_uuid(),
  project_id           uuid not null references public.projects(id) on delete cascade,
  workspace_id         uuid not null references public.workspaces(id) on delete cascade,
  invited_by           uuid not null references public.profiles(id) on delete cascade,
  target               public.referral_target not null default 'individual',
  invitee_name         text not null check (length(trim(invitee_name)) > 0),
  invitee_email        text check (invitee_email is null or invitee_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  invitee_phone        text,
  invitee_workspace_id uuid references public.workspaces(id) on delete set null,
  payout_amount        numeric(12,2) not null default 0 check (payout_amount >= 0),
  special_instructions text check (length(special_instructions) <= 2000),
  token                text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  status               public.referral_status not null default 'draft',
  expires_at           timestamptz not null default now() + interval '7 days',
  viewed_at            timestamptz,
  claimed_by           uuid references public.profiles(id) on delete set null,
  claimed_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint invite_has_contact check (invitee_email is not null or invitee_phone is not null)
);
create index referral_invites_project_idx   on public.referral_invites (project_id);
create index referral_invites_ws_idx        on public.referral_invites (workspace_id, status);
create index referral_invites_invited_by_idx on public.referral_invites (invited_by);
create index referral_invites_claimed_by_idx on public.referral_invites (claimed_by) where claimed_by is not null;
create index referral_invites_inv_ws_idx    on public.referral_invites (invitee_workspace_id) where invitee_workspace_id is not null;

create table public.referral_payouts (
  id                 uuid primary key default gen_random_uuid(),
  invite_id          uuid not null unique references public.referral_invites(id) on delete cascade,
  project_id         uuid not null references public.projects(id) on delete cascade,
  payee_id           uuid not null references public.profiles(id) on delete restrict,
  amount             numeric(12,2) not null check (amount >= 0),
  status             public.payout_status not null default 'held',
  released_at        timestamptz,
  stripe_transfer_id text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index referral_payouts_project_idx on public.referral_payouts (project_id);
create index referral_payouts_payee_idx   on public.referral_payouts (payee_id);

create table public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  workspace_id   uuid references public.workspaces(id) on delete cascade,
  project_id     uuid references public.projects(id) on delete cascade,
  opportunity_id uuid references public.opportunities(id) on delete cascade,
  title          text not null,
  body           text,
  read_at        timestamptz,
  created_at     timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc) where read_at is null;
create index notifications_ws_idx   on public.notifications (workspace_id) where workspace_id is not null;
create index notifications_proj_idx on public.notifications (project_id) where project_id is not null;
create index notifications_opp_idx  on public.notifications (opportunity_id) where opportunity_id is not null;

-- remaining FK indexes from migration 01 / this one
create index workspaces_created_by_idx on public.workspaces (created_by) where created_by is not null;

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','workspaces','workspace_members','customers','opportunities','projects','referral_invites','referral_payouts']
  loop
    execute format('create trigger touch_%1$s before update on public.%1$s for each row execute function private.touch_updated_at()', t);
  end loop;
end $$;

