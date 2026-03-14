## ADDED Requirements

### Requirement: TeamMembership records can be destroyed via the admin panel
The system SHALL allow `TeamMembership` records to be destroyed via the admin panel. This enables cleanup of stale or broken membership records without requiring console access.

#### Scenario: Admin can destroy a TeamMembership record
- **WHEN** an admin destroys a TeamMembership record via the admin panel
- **THEN** the record SHALL be removed from the database
- **AND** the affected player SHALL appear in the Unassigned column the next time the relevant planning board is loaded
