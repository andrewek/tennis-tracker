## Context

Users currently have no way to manage their own account details after registering. The sidebar utility section has an inline theme toggle (`<select>`) but no link to any account management page. The `User` resource already has an `update_profile` action accepting `:name`; AshAuthentication's password strategy is configured with `log_out_everywhere on_password_change? true`.

No email-sending infrastructure exists beyond a local Swoosh dev mailbox — no password reset, no confirmation emails. The mailer is intentionally out of scope for this change.

## Goals / Non-Goals

**Goals:**
- Give every authenticated user a personal settings page accessible from the sidebar
- Allow editing name and email address (direct update, no confirmation email)
- Allow changing password via current-password verification
- Move theme preference to a dedicated Preferences sub-page
- Keep routing and auth consistent with the rest of the app

**Non-Goals:**
- Email confirmation flow for email changes (deferred — requires mailer work)
- Password reset via email (deferred)
- Group membership management (separate feature)
- Persisting theme preference server-side (localStorage is sufficient for now)

## Decisions

### 1. Sub-page structure over a single page

Three sub-pages (`/profile`, `/security`, `/preferences`) rather than one long page. Rationale: keeps each LiveView focused and makes future additions (notifications, privacy settings) easy to slot in without growing a single sprawling page. A shared settings layout component handles the sub-nav.

### 2. All sub-pages are LiveViews

Even `/preferences` (which only manipulates localStorage client-side) is a LiveView for layout consistency and to make future server-side preferences easy to add. The theme select fires JS events directly, same as today — the LiveView does no server-side work for theme.

The selector's displayed value (reflecting the stored preference on page load) is set entirely client-side: the LiveView renders the selector with a default value of "system", and the existing `ThemeSelect` JS hook sets the selector's value to match localStorage immediately on mount — the same hook run that applies the theme to the `<html>` element. No `pushEvent` or server round-trip is involved.

### 3. Route placement: `/account/settings/*` outside group scope

Settings are user-global, not group-scoped. Routes live in their own `ash_authentication_live_session` block with only `live_user_required`. No `GroupMountHook` needed.

### 4. Email update: dedicated `update_email` action, no confirmation

A new `update_email` action is added to the `User` resource (separate from `update_profile`). No verification email. Users are responsible for providing a valid address. A future change can add confirmation when the mailer is set up. Keeping the actions separate makes it easy to add password re-entry or email confirmation to `update_email` later without touching the name-update path.

**Alternative considered:** Block email changes entirely until mailer is ready. Rejected — name-only settings would feel incomplete and the security posture of a direct update is acceptable for this app's current audience.

### 5. Password change: AshAuthentication action

AshAuthentication's password strategy generates a `change_password` action on the User resource that requires `:current_password`, `:password`, and `:password_confirmation`. Submitting it via an `AshPhoenix.Form` is consistent with how other forms work. `log_out_everywhere` fires automatically on success, invalidating all sessions — the user will be redirected to sign-in.

### 6. Sidebar: remove inline toggle, add Account Settings link

The `ThemeToggle` widget is removed from the sidebar. In its place, an "Account Settings" link sits above "Sign out". The toggle lives exclusively on the Preferences sub-page with a more polished presentation.

## Risks / Trade-offs

- **Email change without confirmation** → A user could lock themselves out by typo-ing their new email. No password re-entry is required — this is a known trade-off until the mailer is ready. The dedicated `update_email` action makes it straightforward to add password re-entry in a future change without touching name updates.
- **Password change logs out everywhere** → This is intentional and matches the existing `log_out_everywhere` configuration, but users may find it surprising. The UI should warn them before submission.
- **No migration needed** → Email is already a field on the User resource; we're only adding a new action to accept it. Zero schema risk.

## Open Questions

None.
