## ADDED Requirements

### Requirement: Players can have zero or more tags assigned
A `Player` record SHALL support a many-to-many relationship with `Tag` via the `PlayerTag` join resource. A player MAY have any number of tags from any number of categories. No tag is required. A player with no tags is valid.

#### Scenario: Player has no tags
- **WHEN** a player has no PlayerTag records
- **THEN** the player is displayed without any tag chips and participates in all tag filters with the "show untagged" behavior

#### Scenario: Player has tags from multiple categories
- **WHEN** a player has tags from both Age Group and League Gender categories
- **THEN** both sets of tags are associated with the player and returned when the player is loaded with tags

### Requirement: Tag assignment is performed on the player edit page via checkboxes submitted with the form
The player edit page SHALL include a tag section rendered as grouped checkboxes — one checkbox per tag, grouped by TagCategory. Tag assignment is batched with the rest of the player edit form: changes take effect only when the owner saves the form. The player's current tags SHALL be pre-checked. On submit, the LiveView diffs the submitted tag IDs against the player's current tag IDs and creates or destroys PlayerTag records to match.

#### Scenario: Tag section shows all categories and tags for the group
- **WHEN** a group owner opens the player edit page
- **THEN** all TagCategories and their Tags for the group are shown as grouped checkboxes

#### Scenario: Current tags are pre-checked
- **WHEN** a group owner opens the player edit page for a player with existing tags
- **THEN** the checkboxes for the player's current tags are checked

#### Scenario: Owner adds a tag
- **WHEN** a group owner checks a tag checkbox and saves the form
- **THEN** a PlayerTag record is created and the player now has that tag

#### Scenario: Owner removes a tag
- **WHEN** a group owner unchecks a tag checkbox and saves the form
- **THEN** the PlayerTag record is destroyed and the player no longer has that tag

#### Scenario: Unchecking all tags in a category removes all tag assignments for that category
- **WHEN** a group owner unchecks all tag checkboxes for a category and saves
- **THEN** all PlayerTag records for that category are destroyed for the player

#### Scenario: Group member cannot assign tags
- **WHEN** a user with GroupMembership :member views the player edit page
- **THEN** the tag checkboxes are not shown or are read-only

### Requirement: Tags are displayed on the player show page grouped by category
The player show page SHALL display all tags assigned to the player, grouped by their TagCategory name.

#### Scenario: Tags displayed by category
- **WHEN** a player show page is rendered for a player with tags in multiple categories
- **THEN** tags are shown grouped under their category names

#### Scenario: No tags displays nothing
- **WHEN** a player show page is rendered for a player with no tags
- **THEN** no tag section or empty tag section is shown (no visual clutter)
