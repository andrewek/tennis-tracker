## ADDED Requirements

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
