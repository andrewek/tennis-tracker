## Why

Users have no way to manage their own account — name, email, password, and UI preferences are all inaccessible after initial registration. A personal settings page gives every authenticated user control over their own account regardless of group membership or role.

## What Changes

- Add a new "Account Settings" link to the sidebar utility section (above Sign Out, below Admin)
- Remove the inline theme toggle widget from the sidebar (it moves to the Preferences sub-page)
- Add new routes under `/account/settings/*` accessible to all authenticated users
- Introduce three sub-pages as LiveViews:
  - **Profile** (`/account/settings/profile`) — edit name and email address
  - **Security** (`/account/settings/security`) — change password using current password verification
  - **Preferences** (`/account/settings/preferences`) — theme selection (light/dark/system), localStorage-backed
- Add a new `update_email` action to the `User` resource
- No email confirmation flow (mailer deferred to a future change)
- Password change uses AshAuthentication's built-in mechanism; existing `log_out_everywhere` on password change handles session invalidation

## Capabilities

### New Capabilities

- `account-settings`: Personal account settings page with profile, security, and preferences sub-pages

### Modified Capabilities

- `sidenav-layout`: Sidebar utility section gains an Account Settings link and loses the inline theme toggle widget
- `user-auth`: User resource gains an action to update email address

## Impact

- `lib/tennis_tracker/accounts/user.ex` — new update action for email
- `lib/tennis_tracker_web/components/layouts.ex` — sidebar link added, theme toggle removed
- `lib/tennis_tracker_web/router.ex` — new routes under `/account/settings`
- New LiveView modules under `lib/tennis_tracker_web/live/account/`
- No new dependencies; no database migrations required
