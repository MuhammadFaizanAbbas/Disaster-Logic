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

The frontend targets project `uysazcppnkvsjlhdsveq` in Muhammad Faizan Abbas's organization. Database and Edge Function changes are managed through the connected Supabase project rather than stored in this static frontend repository. For a local preview, run `python3 -m http.server 8080` and visit `http://localhost:8080`; use HTTP rather than opening a `file://` URL.

Create and confirm your own account, then follow [setup.md](docs/setup.md) to grant the first platform administrator, configure Supabase Auth redirects/SMTP, and create the first workspace. No privileged test account was created. `js/config.js` contains only the public URL and publishable key.

Read [schema.md](docs/schema.md) for table relationships and role access, [api.md](docs/api.md) for function actions, and [booking-integration.md](docs/booking-integration.md) for form submission details. The setup guide explains remaining provider configuration and testing limits.

## Files

| Path | Purpose |
|---|---|
| `index.html`, `login.html`, `css/`, `assets/` | Authenticated app entry, dedicated login page, styles, local font and illustrated map |
| `js/live-app.js` | Authentication and live dashboard views |
| `js/api.js`, `js/config.js` | Supabase client and request mapping |
| `js/booking.js` | Public/internal booking form and validation |
| `js/vendor/supabase.js` | Bundled Supabase JS 2.99.3 |
| `tests/database_workflows.sql` | Transactional workflow/access tests; all fixtures roll back |

`index.html` loads the live application and sends signed-out users to `login.html`. Every dashboard view is rendered from Supabase responses; the obsolete sample-data renderer has been removed.

Payment/payout fields record accounting state; payment processing and automated invitation delivery need configured external providers. The Flood Team's detailed room, drying, contract, and payment tables are supported by the schema; this frontend provides the core dashboards and workflow forms described above.
