## MODIFIED Requirements

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
