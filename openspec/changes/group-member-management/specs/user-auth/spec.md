## ADDED Requirements

### Requirement: User resource has an :invite action for owner-initiated account creation
The `User` resource SHALL expose an `:invite` action that accepts an `email` and a plaintext `password` argument. The action SHALL hash the password using AshAuthentication's `HashPasswordChange` and create a new User with role `:member`. This action is intended for internal use only and SHALL NOT be accessible to arbitrary actors.

The action SHALL declare no permissive policy (no `authorize_if`). Its inaccessibility to arbitrary actors is enforced by the absence of a passing policy — any call with a real actor and the default `authorize?: true` will be denied. Authorization for who may trigger the invite flow (group owners and system admins) is enforced one layer up, at the `add_member_by_email` domain function, which calls `:invite` with `authorize?: false`.

#### Scenario: :invite creates a user with a hashed password
- **WHEN** the :invite action is called with a valid email and plaintext password
- **THEN** a new User record is created, the password is stored hashed, and the plaintext is not persisted

#### Scenario: :invite fails if email is already taken
- **WHEN** the :invite action is called with an email that matches an existing User
- **THEN** an error is returned and no duplicate user is created

#### Scenario: :invite sets user role to :member
- **WHEN** the :invite action is called
- **THEN** the created user's role is :member
