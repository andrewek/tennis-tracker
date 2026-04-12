## MODIFIED Requirements

### Requirement: Sidebar contains utility links
The sidebar SHALL contain a "Switch Organization" link, an "Account Settings" link, and a "Sign out" link. An "Admin" link SHALL be shown only to system admin users. The inline theme toggle widget SHALL NOT appear in the sidebar.

#### Scenario: Standard user sees utility links
- **WHEN** a non-admin authenticated user views the sidebar
- **THEN** the sidebar SHALL contain "Switch Organization" (→ `/groups`), "Account Settings" (→ `/account/settings/profile`), and "Sign out"
- **THEN** the sidebar SHALL NOT contain an "Admin" link
- **THEN** the sidebar SHALL NOT contain an inline theme toggle widget

#### Scenario: Admin user sees admin link
- **WHEN** a system admin user views the sidebar
- **THEN** the sidebar SHALL contain "Switch Organization" (→ `/groups`), "Admin" (→ `/admin`), "Account Settings" (→ `/account/settings/profile`), and "Sign out" in that order
- **THEN** the sidebar SHALL NOT contain an inline theme toggle widget

> **Note:** The Switch Organization page shown to admins SHALL list only the groups they are explicitly a member of — not all groups in the system. This scoping behavior belongs to the Switch Organization capability and should be confirmed or specified there.

### Requirement: Sidebar retains group context on account settings pages
When the user navigates to any `/account/settings/*` page, the sidebar SHALL display the most recently visited group's navigation (name, nav links, Switch Organization). If the user has not visited any group in the current session, the group navigation SHALL be omitted without error.

#### Scenario: User navigates to account settings after visiting a group
- **WHEN** a user has previously visited a group-scoped page in the current session
- **AND** they navigate to any `/account/settings/*` page
- **THEN** the sidebar SHALL display the group name, group nav links, and Switch Organization link for the last-visited group

#### Scenario: User navigates to account settings with no prior group visit
- **WHEN** a user navigates to any `/account/settings/*` page without having visited a group-scoped page in the current session
- **THEN** the sidebar SHALL render without error, showing only the utility links (Account Settings, Sign out)
