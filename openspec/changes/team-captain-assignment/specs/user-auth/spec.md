## ADDED Requirements

### Requirement: User records have an optional name attribute
The `User` resource SHALL have an optional `:name` attribute (string, nullable). No uniqueness constraint applies. When displaying a user's identity anywhere in the UI, the system SHALL use `name` if present and fall back to `email` when `name` is nil or empty.

#### Scenario: User can be created without a name
- **WHEN** a User record is created without providing a name
- **THEN** the record is saved successfully with name nil

#### Scenario: User can be created with a name
- **WHEN** a User record is created with a name value
- **THEN** the record is saved successfully and name is stored

#### Scenario: User name can be updated
- **WHEN** an existing User's name is updated to a new value
- **THEN** the change is persisted

#### Scenario: Display label falls back to email when name is nil
- **WHEN** a User has name nil and is displayed in the UI
- **THEN** the user's email is shown as the display label

#### Scenario: Display label uses name when present
- **WHEN** a User has a non-nil name and is displayed in the UI
- **THEN** the user's name is shown as the display label
