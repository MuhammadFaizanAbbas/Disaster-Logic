# Service booking frontend

Open `index.html` directly and select **New Service Request**, or use `index.html#new-service`.

The form and its behavior live in `js/booking.js`; its styles live in `css/booking.css`.
The dark-mode preference is managed by `js/theme.js` and saved under `disaster-logic-theme`.
Customer details and attachments stay in memory during navigation; they are not saved in browser storage.

All four sections and the final request button are visible immediately. Users can fill them in any
order; changing an answer never hides another section or automatically scrolls the page.

The booking page fills the workspace beside the sidebar, without the dashboard toolbar.
On mobile, the navigation toggle is part of the progress strip.
The progress bar sticks to the top of the viewport and becomes compact on scroll.
Its fill advances smoothly as valid details are entered, with two overlapping water waves and animated
completion markers. Each section contributes 25%; valid contact fields fill their section gradually.
The default schedule counts once the preceding sections are complete, or after a dispatch control is
changed. A valid, fully completed form reaches 100%; this does not mean it has been submitted.
Waves settle at completion. Reduced-motion users see a static fill and instant progress updates.
Every step label is always available for jumping to that section.

Contact details are checked on input, change, and focus loss. Inline messages explain invalid fields.
The final **Confirm & Request** button reads current values (including autofill) and validates the
whole form before preparing or submitting a request. Notes and attachments remain optional.
The **Opportunity type** field at the end requires an explicit **Public** or **Private** selection,
which is retained in the draft and included in the final section's completion check.

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
- `opportunity_type`: `public` or `private` (required).
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
