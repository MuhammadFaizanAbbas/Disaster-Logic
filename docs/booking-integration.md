# Service booking frontend

Open `index.html` directly and select **New Service Request**, or use `index.html#new-service`.

The form and its behavior live in `js/booking.js`; its styles live in `css/booking.css`.
The dark-mode preference is managed by `js/theme.js` and saved under `disaster-logic-theme`.
Customer details and attachments stay in memory during navigation; they are not saved in browser storage.

Sections unlock in order: a valid ZIP or captured location, an explicitly selected service,
valid customer details, then dispatch preferences. Changing an earlier answer to an invalid value
locks the later sections without clearing their data. Section reveals and progress transitions
respect the browser's reduced-motion preference.

The progress bar sticks immediately below the app header and becomes compact on scroll.
Available step labels can be selected to return to the corresponding section.

## Submission hook

Register your API integration after `js/booking.js` has loaded:

```js
window.BookingView.setSubmitHandler(async ({ request, files }) => {
  // Send request to your booking API and upload files using your integration.
  // Resolve only after the request has been accepted; throw on any failure.
});
```

`request` contains:

- `location`: `postal_code` and optional `coordinates` (latitude/longitude).
- `service_type`: the selected service ID.
- `customer`: `full_name`, `phone`, and `email`.
- `damage_notes`.
- `dispatch`: `priority`, `preferred_date`, `time_window`, `arrival_notice`, and `time_zone`.

`files` is an array of browser `File` objects. No files are uploaded by this frontend alone.
Use `window.BookingView.getPayload()` to inspect the current request structure.

Until a submission handler is registered, a valid form shows that the request has **not** been submitted.
It also emits a bubbling `booking:prepared` event with `{ request, files }` as its detail.
The form retains entered details when an API handler fails.

The map is a local illustrated preview, not a live coverage or ZIP lookup.
The **Use location** button captures coordinates with the visitor's browser permission.
Connect your mapping/coverage lookup when integrating the backend.
