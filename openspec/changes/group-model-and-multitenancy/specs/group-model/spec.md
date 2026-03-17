## ADDED Requirements

### Requirement: Group resource is the root tenant entity
The system SHALL provide a `Group` Ash resource in the `TennisTracker.Groups` domain with attributes `id` (UUID v7), `name` (string, non-nullable), and `slug` (string, non-nullable, unique). Group SHALL NOT have multitenancy configured — it IS the tenant, not a tenant-scoped resource.

#### Scenario: Group can be created with a name and slug
- **WHEN** a Group record is created with a valid name and slug
- **THEN** the record is saved successfully

#### Scenario: Group slug must be unique
- **WHEN** a second Group is created with the same slug as an existing Group
- **THEN** a uniqueness error is returned and no duplicate is created

#### Scenario: Group name is required
- **WHEN** a Group record is created without a name
- **THEN** a validation error is returned

### Requirement: GroupMembership links users to groups with a role
The system SHALL provide a `GroupMembership` Ash resource in the `TennisTracker.Groups` domain with `user_id` (belongs_to User, non-nullable), `group_id` (belongs_to Group, non-nullable), and `role` (atom, allowed values `:owner` and `:member`, non-nullable). GroupMembership SHALL NOT have multitenancy configured. The combination of `(user_id, group_id)` SHALL be unique.

#### Scenario: GroupMembership can be created with role :owner
- **WHEN** a GroupMembership record is created with a valid user_id, group_id, and role :owner
- **THEN** the record is saved successfully

#### Scenario: GroupMembership can be created with role :member
- **WHEN** a GroupMembership record is created with a valid user_id, group_id, and role :member
- **THEN** the record is saved successfully

#### Scenario: A user can belong to multiple groups
- **WHEN** a User has GroupMembership records for two different Groups
- **THEN** both records exist and are valid

#### Scenario: A user cannot have two memberships in the same group
- **WHEN** a second GroupMembership is created with the same user_id and group_id as an existing record
- **THEN** a uniqueness error is returned

#### Scenario: Invalid role value is rejected
- **WHEN** a GroupMembership is created with a role value outside [:owner, :member]
- **THEN** a validation error is returned

### Requirement: Seeds create a default Group with the admin user as owner
The seed script SHALL create a default `Group` record and a corresponding `GroupMembership` linking the seeded admin user as `:owner`. Seeding SHALL be idempotent.

#### Scenario: Seeds create the default group
- **WHEN** the seed script is run on a fresh database
- **THEN** at least one Group record exists

#### Scenario: Admin user is an owner of the default group
- **WHEN** the seed script is run
- **THEN** a GroupMembership exists with the admin user's id, the default group's id, and role :owner

#### Scenario: Seeds are idempotent
- **WHEN** the seed script is run more than once
- **THEN** no duplicate Group or GroupMembership records are created
