## Requirements

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

### Requirement: GroupMembership read access is granted to any group member
Any authenticated user with a `GroupMembership` for a group SHALL be permitted to read all `GroupMembership` records for that group. This replaces the previous behavior where read access was limited to group owners and the user whose own record it was.

#### Scenario: Group member can list all memberships in their group
- **WHEN** a user with GroupMembership :member reads GroupMembership records for their group
- **THEN** all membership records for that group are returned

#### Scenario: Group owner can list all memberships in their group
- **WHEN** a user with GroupMembership :owner reads GroupMembership records for their group
- **THEN** all membership records for that group are returned

#### Scenario: User outside the group cannot read GroupMembership records
- **WHEN** a user with no GroupMembership for a group attempts to read its memberships
- **THEN** the read is denied

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

### Requirement: GroupMembership has an :update_role action
The `GroupMembership` resource SHALL expose an `:update_role` action that accepts a `role` attribute change. This action SHALL be authorized only for group owners. A group owner SHALL NOT be permitted to use this action to change their own membership's role.

#### Scenario: Group owner can update another member's role
- **WHEN** a group owner calls `:update_role` on another member's GroupMembership with a valid role
- **THEN** the role is updated successfully

#### Scenario: Group owner cannot update their own role via :update_role
- **WHEN** a group owner calls `:update_role` on their own GroupMembership
- **THEN** the action is denied

#### Scenario: No guard prevents demoting the only other owner
- **WHEN** a group owner calls `:update_role` to demote another owner who is the sole remaining other owner
- **THEN** the action succeeds; no application-layer guard enforces a minimum owner count

#### Scenario: Group member (non-owner) cannot update roles
- **WHEN** a user with role :member calls `:update_role` on any GroupMembership
- **THEN** the action is denied

### Requirement: GroupMembership destroy is blocked for self-removal
A group owner SHALL NOT be able to destroy their own `GroupMembership`. The existing destroy policy (group owners can destroy memberships) SHALL be extended with a `forbid_if` that blocks the action when the membership's `user_id` matches the actor's `id`.

#### Scenario: Group owner can remove another member's GroupMembership
- **WHEN** a group owner calls destroy on another member's GroupMembership
- **THEN** the record is destroyed successfully

#### Scenario: Group owner cannot destroy their own GroupMembership
- **WHEN** a group owner calls destroy on their own GroupMembership
- **THEN** the action is denied

#### Scenario: No guard prevents removing the only other owner
- **WHEN** a group owner destroys another owner's GroupMembership and that owner is the sole remaining other owner
- **THEN** the action succeeds; no application-layer guard enforces a minimum owner count

### Requirement: Groups domain exposes add_member_by_email function
The `TennisTracker.Groups` domain SHALL expose an `add_member_by_email/3` function (or equivalent) that accepts an email address, a role, and options (including `actor:` and `tenant:`). It SHALL find or create a user by that email, then create a `GroupMembership`. It SHALL return a result tuple indicating whether a new user was created and, if so, the plaintext temporary password.

#### Scenario: add_member_by_email with an existing user creates membership
- **WHEN** add_member_by_email is called with an email matching an existing User
- **THEN** a GroupMembership is created and {:ok, %{new_user?: false, temp_password: nil, membership: _}} is returned

#### Scenario: add_member_by_email with a new email creates user and membership
- **WHEN** add_member_by_email is called with an email that has no existing User
- **THEN** a new User is created, a GroupMembership is created, and {:ok, %{new_user?: true, temp_password: <<plaintext>>, membership: _}} is returned

#### Scenario: add_member_by_email with an already-member email returns an error
- **WHEN** add_member_by_email is called with an email belonging to a user already in the group
- **THEN** an error tuple is returned and no duplicate membership is created

#### Scenario: add_member_by_email handles concurrent user registration
- **WHEN** add_member_by_email is called with an email that has no existing User, but a user self-registers with that email between the lookup and the invite
- **THEN** the unique-identity conflict is detected, the newly registered user is looked up, a GroupMembership is created for them, and `{:ok, %{new_user?: false, temp_password: nil, membership: _}}` is returned
