## 1. User Resource

- [x] 1.1 Add a new `update_email` action on `User` to accept `:email`
- [x] 1.2 Add policy for the email update action (actor can only update their own email)
- [x] 1.3 Verify AshAuthentication generates a `change_password` action; confirm it works with `AshPhoenix.Form`

## 2. Routing

- [x] 2.1 Add a new `ash_authentication_live_session` block for account settings routes (user required, no group hook)
- [x] 2.2 Add routes: `/account/settings/profile`, `/account/settings/security`, `/account/settings/preferences`
- [x] 2.3 Add a redirect from `/account/settings` → `/account/settings/profile`

## 3. Sidebar

- [x] 3.1 Remove the inline `<.theme_toggle />` component from the sidebar utility section in `layouts.ex`
- [x] 3.2 Add "Account Settings" link to the sidebar above "Sign out" and below "Admin"

## 4. Settings Layout Component

- [x] 4.1 Create a shared settings layout component (or nested layout) that renders the sub-nav (Profile / Security / Preferences) and wraps the inner content
- [x] 4.2 Apply active-link styling to the currently selected sub-nav item

## 5. Profile Sub-Page

- [x] 5.1 Create `TennisTrackerWeb.Live.Account.ProfileLive` at `lib/tennis_tracker_web/live/account/profile_live.ex`
- [x] 5.2 Mount two separate forms: one via `AshPhoenix.Form.for_update` against `update_profile` (name field), one via `AshPhoenix.Form.for_update` against `update_email` (email field); both pre-populated with current user values
- [x] 5.3 Handle form submit: call `AshPhoenix.Form.submit`, show success flash or re-render with errors
- [x] 5.4 Write LiveView tests for the profile page (view loads, name update succeeds, email update succeeds, duplicate email shows error)

## 6. Security Sub-Page

- [x] 6.1 Create `TennisTrackerWeb.Live.Account.SecurityLive` at `lib/tennis_tracker_web/live/account/security_live.ex`
- [x] 6.2 Mount the password change form using `AshPhoenix.Form` against the AshAuthentication `change_password` action
- [x] 6.3 Include a visible warning that saving a new password will sign the user out of all sessions
- [x] 6.4 Handle form submit: on success redirect to sign-in; on error re-render with errors
- [x] 6.5 Write LiveView tests (page loads with warning, wrong current password shows error, successful change redirects to sign-in)

## 7. Preferences Sub-Page

- [x] 7.1 Create `TennisTrackerWeb.Live.Account.PreferencesLive` at `lib/tennis_tracker_web/live/account/preferences_live.ex`
- [x] 7.2 Render the theme selector using the existing `ThemeToggle` component (or inline equivalent) with improved visual presentation (labels, radio buttons or styled select)
- [x] 7.3 Extend the `ThemeSelect` JS hook to also set the selector element's value from localStorage on mount (in addition to applying the theme to `<html>`), so the selector displays the stored preference without a server round-trip
- [x] 7.4 Write a LiveView test (page loads, theme select element is present)
