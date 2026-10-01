# Booking integration

The booking form in `js/booking.js` is connected by `js/live-app.js` to `js/api.js`. Submit creates an Opportunity in the selected workspace through the authorization-checked `submit_booking` RPC. Successful requests show a real receipt; failures preserve entered values and show the API error.

- Public form: `index.html?booking=WORKSPACE_PUBLIC_KEY`.
- Internal form: sign in, select a workspace, and choose New Service Request.
- Enabled services come from the workspace configuration.
- ZIP/postal code is required for matching. Geolocation captures coordinates but does not reverse-geocode a ZIP.
- Public submissions are public Opportunities. Internal members may also choose private visibility.
- Attachments upload into a private bucket with an expiring capability; allowed formats are JPEG, PNG, WebP, MP4, WebM and MOV, up to five files, 10 MB each.

The adapter maps customer, service, damage notes, dispatch priority/date/window, arrival notice, coordinates and visibility to `submit_booking`. It then uploads the files and registers their metadata through `attach_media`. Download URLs expire after five minutes and require authorized access.

A receipt stays in page memory during retries to prevent another Opportunity when an upload fails. Reloading clears that receipt. The map is a local illustration, not a live ZIP coverage map. Host over HTTP for local development and HTTPS in production.

The reusable integration hook remains:

```js
window.BookingView.setSubmitHandler(async ({ request, files }) => {
  return window.DisasterAPI.submitBooking(workspacePublicKey, { request, files });
});
```

`request` contains `location`, `service_type`, `opportunity_type`, `customer`, `damage_notes`, and `dispatch`; `files` contains browser File objects. The live application already registers this handler for you.
