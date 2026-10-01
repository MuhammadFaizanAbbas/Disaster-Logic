# Disaster Logic setup

The application is plain HTML, CSS, and JavaScript. Serve the project folder from a static HTTPS host. No Node, PHP, Express, or application server is needed in production. Supabase provides Auth, Postgres, private file storage, and the five deployed Edge Functions.

## Existing Supabase project

- Organization: Muhammad Faizan Abbas
- Project: Disaster Logic
- Project ref: `uysazcppnkvsjlhdsveq`
- Browser configuration: `js/config.js` contains the public API URL and publishable key only.
- Five functions: `opportunities`, `my-projects`, `quick-referral`, `customers`, `profile`.
- All five functions verify JWTs and also validate the caller with Supabase Auth.

The schema changes in this package are already applied to this project. Do not rerun migration SQL manually against the existing database. The migration folder is a versioned record and can recreate the schema on a new Supabase project.

## First administrator

There were no Auth users or workspaces when this work was verified. Create your own account in the app and confirm your email. In the Supabase SQL Editor, run this once with **your confirmed account email**:

```sql
do $$
declare v_user uuid;
begin
  select id into v_user from auth.users
  where lower(email) = lower('REPLACE_WITH_YOUR_EMAIL')
    and email_confirmed_at is not null;
  if v_user is null then raise exception 'Confirmed account not found'; end if;
  update public.profiles set is_platform_admin = true where id = v_user;
end $$;
```

Sign out and back in. The Workspace panel allows you to create a company, choose services, and assign an existing account as its admin. Internal accounts must sign up before a workspace admin adds their email. Configure service areas and user tiers before using provider matching.

No first-account auto-promotion exists: public registration cannot grant platform-admin access.

## Authentication email settings

In Supabase Auth URL Configuration, set your static site's URL and add its allowed redirect URLs. Email sign-in and confirmation links must return to that origin. Include URLs containing the `ref` query parameter for referral sign-in. Configure custom SMTP for real external recipients; Supabase's built-in test mail service has recipient and rate restrictions.

Recipients can sign in with an email link. Individual referral accounts are provisioned in the Edge Function when a link is created; their address remains unconfirmed until they verify it. A provisioning error is returned as `account_warning`; the referral itself remains saved. A recipient may also create their account through the app. Phone-only recipients require a configured Supabase SMS provider and verified phone sign-in; the supplied UI implements email sign-in, so use email invitations for the current UI.

## Public and internal forms

- Public booking: `index.html?booking=WORKSPACE_PUBLIC_KEY`
- Referral portal: `index.html?ref=REFERRAL_TOKEN`
- Internal booking: New Service Request in the signed-in dashboard.

Every workspace has a unique public booking key. Public submission always creates a public Opportunity. An internal member or platform admin may choose Public or Private. The workspace's selected services drive the form. ZIP codes remain required even when geolocation is captured.

Files upload to the private `opportunity-media` bucket using an expiring upload capability. Only authorized project/opportunity viewers can create a signed download URL. Booking retries retain their receipt in page memory to avoid creating another Opportunity after a partial upload failure; refreshing the page clears this retry state.

## Invitations and payment records

Copy/share actions create a usable URL; they do not claim that an SMS or email was delivered. No messaging provider credentials were supplied. Email sign-in delivery uses Supabase Auth's configured provider. `link_sent` is the inherited invitation status name and indicates a generated, claimable link, not a delivery receipt.

Payouts and payments are accounting records. This package does not process Stripe charges, fund escrow, or transfer money. New referral payouts are marked `pending`, with no claim of funds being held.

## Local preview and deployment

Use any static development server. For example, `python3 -m http.server 8080` is a local preview command, not a production backend. Publish the project folder to your static host. Only public assets need hosting; `supabase/`, `tests/`, and documentation may be omitted from the hosted files.

For future backend deployments, authenticate the Supabase CLI, link the project, apply tracked migrations, and deploy the functions. Commands should be checked against the installed CLI's `--help`. Function dependencies are pinned. A generated `database.types.ts` is included for developers; the frontend itself needs no TypeScript compiler.

## Verification and remaining configuration

- All five function sources passed Deno type checking.
- Transactional database tests verify booking, acceptance, all referral modes, recipient identity, tenant isolation, disabled memberships, financial-step isolation, and blocked unauthorized writes. Fixtures are rolled back.
- Browser checks passed for booking, all referral modes, project workflow updates, admin panels and responsive layout with mocked API responses. The real Supabase SDK initialized the unsigned login view without JavaScript errors.
- Deployed functions rejected unauthenticated calls with HTTP 401.
- Supabase performance advisors reported only unused indexes, expected in a fresh database.
- Security advisors flag intentionally callable, authorization-checked SECURITY DEFINER RPCs and the private upload-token table's deny-by-default RLS. Public booking/preview/upload RPCs intentionally use public keys or unguessable tokens. They are not general anonymous table access.
- Signed-in live HTTP tests were not run because creation of a persistent privileged test account was rejected by automatic approval review. Database tests use rollback transactions instead; UI tests use mocked API responses.

The seven default workflow labels are Evaluate, Claim, Scope, Drying Plan, Contracts, Work, and Payments. They are configurable reference rows, not a declaration that the second application's entire workflow UI has been implemented. The supporting job tables are available to the Flood Team dashboard; this frontend includes workflow notes and completion tracking.
