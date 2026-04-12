## Requirements

### Requirement: Account settings are accessible to all authenticated users
The system SHALL provide a personal account settings section at `/account/settings` accessible to any authenticated user regardless of group membership or role.

#### Scenario: Authenticated user navigates to account settings
- **WHEN** an authenticated user navigates to `/account/settings`
- **THEN** they SHALL be redirected to `/account/settings/profile`

#### Scenario: Unauthenticated user is redirected to sign-in
- **WHEN** an unauthenticated user navigates to any `/account/settings/*` path
- **THEN** they SHALL be redirected to the sign-in page

### Requirement: Account settings has a sub-navigation with three sections
The account settings layout SHALL display a sub-navigation with links to Profile, Security, and Preferences. The currently active section SHALL be visually indicated.

#### Scenario: Sub-nav is present on all settings sub-pages
- **WHEN** a user is on any `/account/settings/*` page
- **THEN** the sub-navigation SHALL show links to Profile, Security, and Preferences

#### Scenario: Active section is highlighted
- **WHEN** a user is on `/account/settings/security`
- **THEN** the Security link in the sub-nav SHALL be visually active/selected

### Requirement: Profile sub-page allows editing name and email via separate forms
The Profile settings page SHALL present two independent forms: a name form (backed by `update_profile`) and an email form (backed by `update_email`). Each form SHALL be pre-populated with the user's current value and submitted independently.

#### Scenario: User updates their name
- **WHEN** a user submits the name form with a new name
- **THEN** the user's name SHALL be updated and a success message SHALL be shown

#### Scenario: User updates their email
- **WHEN** a user submits the email form with a new email address
- **THEN** the user's email SHALL be updated and a success message SHALL be shown

#### Scenario: User submits an email already in use
- **WHEN** a user submits the email form with an email that belongs to another account
- **THEN** an error message SHALL be shown and the email SHALL NOT be updated

#### Scenario: Each form is pre-populated
- **WHEN** a user navigates to the Profile settings page
- **THEN** the name form SHALL be pre-filled with the user's current name
- **AND** the email form SHALL be pre-filled with the user's current email address

### Requirement: Security sub-page allows changing password
The Security settings page SHALL allow the authenticated user to change their password by providing their current password, a new password, and a confirmation. On success, all sessions SHALL be invalidated and the user SHALL be redirected to sign-in.

#### Scenario: User changes password with valid inputs
- **WHEN** a user submits the security form with correct current password and matching new password/confirmation
- **THEN** the password SHALL be updated, all sessions SHALL be invalidated, and the user SHALL be redirected to sign-in

#### Scenario: User provides wrong current password
- **WHEN** a user submits the security form with an incorrect current password
- **THEN** an error SHALL be shown and the password SHALL NOT be changed

#### Scenario: New password and confirmation do not match
- **WHEN** a user submits the security form with mismatched new password and confirmation
- **THEN** an error SHALL be shown and the password SHALL NOT be changed

#### Scenario: User is warned that changing password will log them out everywhere
- **WHEN** a user views the Security settings page
- **THEN** a notice SHALL inform them that saving a new password will sign them out of all sessions

### Requirement: Preferences sub-page allows selecting UI theme
The Preferences settings page SHALL allow the authenticated user to select their preferred UI theme (System, Light, or Dark). The selection SHALL be persisted in browser localStorage and take effect immediately without a page reload.

#### Scenario: User selects Light theme
- **WHEN** a user selects "Light" on the Preferences page
- **THEN** the UI theme SHALL switch to light mode immediately

#### Scenario: User selects Dark theme
- **WHEN** a user selects "Dark" on the Preferences page
- **THEN** the UI theme SHALL switch to dark mode immediately

#### Scenario: User selects System theme
- **WHEN** a user selects "System" on the Preferences page
- **THEN** the theme SHALL follow the operating system preference

#### Scenario: Current theme preference is shown as selected on page load
- **WHEN** a user navigates to the Preferences page
- **THEN** the theme selector SHALL show the currently active theme (as stored in localStorage)
- **NOTE** this is satisfied client-side: the LiveView renders the selector with a default of "system"; the `ThemeSelect` JS hook sets the selector's value from localStorage on mount, with no server round-trip
