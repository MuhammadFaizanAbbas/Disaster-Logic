# Disaster-Logic

Responsive disaster-repair admin console and service booking frontend built with plain HTML, CSS, and JavaScript.

Open `index.html` in a browser. No server, package installation, or build step is required.

## Features

- Dashboard, opportunities, projects, referrals, customers, personnel, and service views.
- Responsive sidebar and persistent light/dark theme.
- Complete service booking form with all sections visible, smooth completion animations, and a compact sticky progress bar.
- Full-width booking workspace without the dashboard toolbar, flowing progress animation, and inline contact validation.
- Customer details, attachment selection, and emergency or scheduled dispatch preferences.
- Locally bundled Source Sans 3 font.

## Structure

```text
index.html
assets/      Fonts, licenses, and the illustrated map preview
css/         Layout, typography, booking, and theme styles
js/          Views, example data, icons, booking behavior, and theme state
docs/        Booking API integration notes
```

Booking data is kept in memory while navigating. Actual submission and file uploads are not connected yet.
The map is an illustrated preview, not a live location or coverage lookup.

See [the booking integration guide](docs/booking-integration.md) for the API submission hook.
