# Browser API contract

Use `DisasterAPI.call(functionName, action, fields)` after sign-in. It sends the session access token, unwraps `{ data: result }`, and reports `{ error: message }`. All Edge Function calls use POST, accept OPTIONS for CORS, and validate the authenticated caller. Paginated list endpoints return `{ items, count }` and accept bounded `offset`/`limit`.

| Function | Actions |
|---|---|
| `opportunities` | `list`, `get`, `accept`, `decline`, `stats`, `form`, `referral_board`, `accept_referral` |
| `my-projects` | `list`, `get`, `assign`, `update`, `set_status`, `steps`, `save_step`, `upload_token` |
| `quick-referral` | `list`, `contacts`, `workspaces`, `create`, `refer_opportunity`, `claim`, `revoke` |
| `customers` | `list`, `get`, `save` |
| `profile` | `me`, `update`, `notifications`, `mark_read`, `get_availability`, `set_availability`, `workspaces`, `create_workspace`, `members`, `add_member`, `member_settings`, `member_services`, `services`, `save_services`, `locations`, `save_location` |

Workspace actions normally receive `workspace_id`; record actions receive `id` or `project_id`. Role checks run on the backend. The function sources define the exact remaining fields.

```js
const { project_id } = await DisasterAPI.call('opportunities', 'accept', {
  workspace_id: activeWorkspaceId,
  id: opportunityId
});

const invitation = await DisasterAPI.call('quick-referral', 'create', {
  workspace_id: activeWorkspaceId,
  project_id,
  target: 'individual',
  name: 'Contractor name',
  email: 'contractor@example.com',
  payout_amount: 0,
  instructions: 'Contact the customer before arrival.'
});
```

Workspace invitations use `target_workspace_id`; open listings use `target: 'opportunities'`. Creation returns a token; the frontend builds `?ref=TOKEN` on its own origin. `refer_opportunity` accepts an `opportunity_id` and atomically creates the project/invitation. Individual account provisioning may return an `account_warning`; the saved invitation still exists.

Public booking uses `get_booking_form`, `submit_booking`, and `attach_media` RPCs. Anonymous invitation preview uses `preview_referral`; claiming requires verified sign-in through the `quick-referral` function. These limited RPCs use booking keys or invitation/upload capabilities and grant no general anonymous access to customer/project tables.

No service-role key belongs in browser code. Functions use caller-scoped clients so RLS remains in force; privileged Auth is used only to provision an authorized invitation's unconfirmed recipient.
