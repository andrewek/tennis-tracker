## ADDED Requirements

### Requirement: Tag category names and tag names may not contain a colon character
`TagCategory.name` and `Tag.name` SHALL be validated to reject any value containing the `:` character. This constraint is enforced at the application layer via Ash resource validation. The `:` character is reserved as the delimiter in CSV tag column headers.

#### Scenario: Tag category name with colon is rejected
- **WHEN** a group owner attempts to create or update a `TagCategory` with a name containing `:`
- **THEN** the action fails with a validation error indicating colons are not allowed in category names

#### Scenario: Tag name with colon is rejected
- **WHEN** a group owner attempts to create or update a `Tag` with a name containing `:`
- **THEN** the action fails with a validation error indicating colons are not allowed in tag names

#### Scenario: Tag category name without colon is accepted
- **WHEN** a group owner creates a `TagCategory` with a name that does not contain `:`
- **THEN** the record is saved successfully

#### Scenario: Tag name without colon is accepted
- **WHEN** a group owner creates a `Tag` with a name that does not contain `:`
- **THEN** the record is saved successfully
