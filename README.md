# Disaster Logic

Multi-workspace booking and referral application using plain HTML, CSS, JavaScript, and Supabase. The browser talks directly to Supabase Auth, Postgres, private Storage, and five Edge Functions. No application server or frontend build is required.

## Implemented

- Platform administrators, workspace administrators, internal team members, and project-scoped referral participants.
- Workspace public booking links and authenticated internal bookings, with private attachment uploads.
- Separate Opportunities; Accept creates a Project atomically.
- My Projects, internal assignments, status transitions, and seven configurable workflow steps.
- Quick Referral: Assign to Individual, Assign to Workspace, or Show in Opportunities.
- Unique expiring referral URLs, verified recipient claims, previous referral contacts, and revocation.
- Customers, profile, availability, notifications, workspace services, ZIP coverage, and dispatch tiers.
- RLS, protected writes, authorization-checked RPCs, indexes, and rolled-back database regression tests.

## Start here

The backend changes are already deployed to project `uysazcppnkvsjlhdsveq` in Muhammad Faizan Abbas's organization. Host this folder on a static HTTPS host. For a local preview, run `python3 -m http.server 8080` and visit `http://localhost:8080`; use HTTP rather than opening a `file://` URL.

Create and confirm your own account, then follow [setup.md](docs/setup.md) to grant the first platform administrator, configure Supabase Auth redirects/SMTP, and create the first workspace. No privileged test account was created. `js/config.js` contains only the public URL and publishable key.

Read [schema.md](docs/schema.md) for table relationships and role access, [api.md](docs/api.md) for function actions, and [booking-integration.md](docs/booking-integration.md) for form submission details. The setup guide explains remaining provider configuration and testing limits.

## Files

| Path | Purpose |
|---|---|
| `index.html`, `css/`, `assets/` | Static layout, styles, local font and illustrated map |
| `js/live-app.js` | Authentication and live dashboard views |
| `js/api.js`, `js/config.js` | Supabase client and request mapping |
| `js/booking.js` | Public/internal booking form and validation |
| `js/vendor/supabase.js` | Bundled Supabase JS 2.99.3 |
| `supabase/migrations/` | Exact applied migration history, including prior work |
| `supabase/functions/` | Source and pinned dependencies for the five deployed functions |
| `supabase/database.types.ts` | Generated database types for future development |
| `tests/database_workflows.sql` | Transactional workflow/access tests; all fixtures roll back |

The original `js/app.js` and `js/data.js` are retained as unloaded design references. `index.html` loads the live application instead; no sample dashboard data is presented to users.

Payment/payout fields record accounting state; payment processing and automated invitation delivery need configured external providers. The Flood Team's detailed room, drying, contract, and payment tables are supported by the schema; this frontend provides the core dashboards and workflow forms described above.
