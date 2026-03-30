## Requirements

### Requirement: Tag categories and tags are group-scoped
`TagCategory` and `Tag` records SHALL be tenant-scoped by `group_id`. A group's taxonomy is completely independent of all other groups. Group members SHALL be able to read categories and tags. Only group owners SHALL be able to create, update, or destroy them.

#### Scenario: Group member can read tag categories
- **WHEN** a user with GroupMembership :member reads tag categories for their group
- **THEN** the categories are returned successfully

#### Scenario: Group member cannot create a tag category
- **WHEN** a user with GroupMembership :member attempts to create a TagCategory
- **THEN** the action is denied

#### Scenario: Group owner can create a tag category
- **WHEN** a user with GroupMembership :owner creates a TagCategory with a valid name
- **THEN** the record is saved and the category is available for the group

#### Scenario: Categories from other groups are not visible
- **WHEN** a user views tag categories for group A
- **THEN** no TagCategory records from group B are returned

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

### Requirement: Tag category names are unique within a group
No two `TagCategory` records within the same group SHALL share the same name (case-sensitive).

#### Scenario: Duplicate category name is rejected
- **WHEN** a group owner attempts to create a TagCategory with a name that already exists in the group
- **THEN** the action fails with a uniqueness error

#### Scenario: Same category name in different groups is allowed
- **WHEN** two different groups each have a TagCategory named "Availability"
- **THEN** both records coexist and are valid

### Requirement: Tag names are unique within a category within a group (case-insensitive)
No two `Tag` records in the same `TagCategory` within the same group SHALL share the same name (case-insensitive). Tags in different categories MAY share the same name.

#### Scenario: Duplicate tag name within a category is rejected
- **WHEN** a group owner attempts to create a Tag with a name that matches (case-insensitively) a name already used in the same category
- **THEN** the action fails with a uniqueness error

#### Scenario: Tag name differing only by case is rejected within a category
- **WHEN** a group owner attempts to create a Tag named "active" in a category that already has a Tag named "Active"
- **THEN** the action fails with a uniqueness error

#### Scenario: Same tag name in different categories is allowed
- **WHEN** a group owner creates a Tag named "Active" in category "Availability" and another "Active" in category "Status"
- **THEN** both tags are created successfully

### Requirement: Deleting a tag category cascades to its tags and their join records
When a `TagCategory` is destroyed, all `Tag` records in that category SHALL be destroyed. All `PlayerTag` and `SeasonRulesDefaultTag` records referencing those tags SHALL also be destroyed.

#### Scenario: Category deletion removes all child tags
- **WHEN** a group owner destroys a TagCategory that has tags
- **THEN** all Tag records in that category are also destroyed

#### Scenario: Category deletion removes all player tag assignments for those tags
- **WHEN** a group owner destroys a TagCategory whose tags are assigned to players
- **THEN** all PlayerTag join records for those tags are also destroyed

#### Scenario: Category deletion removes all season rules default tags for those tags
- **WHEN** a group owner destroys a TagCategory whose tags are referenced in SeasonRulesDefaultTag records
- **THEN** all SeasonRulesDefaultTag records for those tags are also destroyed

### Requirement: Tag management UI requires confirmation before deleting a category
The application standard pattern is a confirmation modal before any destructive delete (used for players, teams, and now tags/categories). The UI SHALL always display a confirmation modal before destroying a TagCategory. When the category contains tags, the modal SHALL include the count of tags that will also be deleted.

#### Scenario: Confirmation modal shown for non-empty category
- **WHEN** a group owner initiates deletion of a category containing N tags
- **THEN** a confirmation modal is shown indicating N tags will also be deleted and the operation cannot be undone

#### Scenario: Confirmation modal shown for empty category
- **WHEN** a group owner initiates deletion of a category with zero tags
- **THEN** a confirmation modal is shown before deletion (no special tag-count message needed)

#### Scenario: Owner confirms deletion
- **WHEN** the confirmation modal is shown and the owner confirms
- **THEN** the category and all its tags are destroyed

#### Scenario: Owner cancels deletion
- **WHEN** the confirmation modal is shown and the owner cancels
- **THEN** no records are deleted and the category remains

### Requirement: Tag management UI requires confirmation before deleting a tag
Consistent with the application standard pattern, the UI SHALL display a confirmation modal before destroying a Tag.

#### Scenario: Confirmation modal shown before tag deletion
- **WHEN** a group owner initiates deletion of a Tag
- **THEN** a confirmation modal is shown before the deletion proceeds

#### Scenario: Owner confirms tag deletion
- **WHEN** the confirmation modal is shown and the owner confirms
- **THEN** the tag and all its PlayerTag and SeasonRulesDefaultTag records are destroyed

#### Scenario: Owner cancels tag deletion
- **WHEN** the confirmation modal is shown and the owner cancels
- **THEN** no records are deleted and the tag remains

### Requirement: Deleting a tag cascades to its join records
When a `Tag` is destroyed, all `PlayerTag` and `SeasonRulesDefaultTag` records referencing that tag SHALL be destroyed.

#### Scenario: Tag deletion removes player assignments
- **WHEN** a group owner destroys a Tag assigned to one or more players
- **THEN** all PlayerTag records for that tag are destroyed and affected players no longer have the tag

#### Scenario: Tag deletion removes season rules defaults
- **WHEN** a group owner destroys a Tag referenced in one or more SeasonRulesDefaultTag records
- **THEN** all SeasonRulesDefaultTag records for that tag are destroyed

### Requirement: Tag management is accessible under group settings
A tag management page SHALL be accessible at `/g/:group_slug/settings/tags`. The page SHALL list all tag categories for the group, with their tags, and provide controls to create, rename, and delete categories and tags. Only group owners SHALL see the management controls; members see the taxonomy read-only.

#### Scenario: Owner sees management controls
- **WHEN** a group owner navigates to the tag management page
- **THEN** controls to create, rename, and delete categories and tags are visible

#### Scenario: Member sees taxonomy without controls
- **WHEN** a group member navigates to the tag management page
- **THEN** the tag taxonomy is displayed but no create/edit/delete controls are shown

### Requirement: A preset tag taxonomy can be seeded for a group
A `Tennis.seed_preset_tags!/1` domain function SHALL create a standard set of tag categories and tags for a given group. This function is called from `priv/repo/seeds.exs` for local development. For production groups, it can be invoked via an `iex` shell or AshAdmin. Automatic triggering on group creation is deferred.

The preset taxonomy is:
- Age Group: 18+, 40+, 55+, 65+, 70+
- League Gender: Women's Leagues, Men's Leagues, Mixed Leagues
- NTRP: Can Play Up, Appealing Down
- Availability: Active, Sitting Out, Medical Hold, Roster Fill Only, Limited Availability, Inactive
- Role: Willing to Captain, Sub Only
- Pipeline: Prospective, Needs Follow-up, Incomplete Record

#### Scenario: Preset taxonomy is created for a given group
- **WHEN** `Tennis.seed_preset_tags!/1` is called with a group_id
- **THEN** the preset TagCategory and Tag records are created for that group

#### Scenario: Preset taxonomy does not affect other groups
- **WHEN** `Tennis.seed_preset_tags!/1` is called for group A
- **THEN** no tag categories or tags are added to any other group
