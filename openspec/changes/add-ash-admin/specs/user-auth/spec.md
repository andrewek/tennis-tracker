## ADDED Requirements

### Requirement: Users can authenticate with email and password
The system SHALL support email/password authentication via AshAuthentication. Unauthenticated users SHALL be redirected to the login page when accessing protected routes.

#### Scenario: Valid login redirects to home
- **WHEN** a user submits valid credentials on the login page
- **THEN** the user SHALL be authenticated and redirected to the home page

#### Scenario: Invalid credentials show an error
- **WHEN** a user submits an incorrect email or password
- **THEN** an error message SHALL be shown and the user SHALL remain on the login page

#### Scenario: Unauthenticated access to protected route redirects to login
- **WHEN** an unauthenticated user navigates to a protected route (e.g., `/admin`)
- **THEN** the user SHALL be redirected to the login page

### Requirement: User records have a role attribute
Every `User` record SHALL have a `role` attribute with allowed values `:admin` and `:member`. New users SHALL default to `:member`.

#### Scenario: New user defaults to :member role
- **WHEN** a new User record is created without specifying a role
- **THEN** the user's role SHALL be `:member`

#### Scenario: Role can be set to :admin
- **WHEN** a User record is created or updated with role `:admin`
- **THEN** the record SHALL be saved successfully with role `:admin`

#### Scenario: Invalid role value is rejected
- **WHEN** an attempt is made to set a role value outside `[:admin, :member]`
- **THEN** a validation error SHALL be returned

### Requirement: Dev seeds create an admin user and a member user
The seed script SHALL create two users for local development: one with role `:admin` and one with role `:member`.

#### Scenario: Seed creates admin@example.com
- **WHEN** the seed script is run
- **THEN** a User record with email `admin@example.com` and role `:admin` SHALL exist

#### Scenario: Seed creates user@example.com
- **WHEN** the seed script is run
- **THEN** a User record with email `user@example.com` and role `:member` SHALL exist

#### Scenario: Seeds are idempotent
- **WHEN** the seed script is run more than once
- **THEN** no duplicate user records SHALL be created
