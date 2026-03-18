## REMOVED Requirements

### Requirement: Full-bleed layout fills the viewport height
**Reason**: `Layouts.full_bleed` is removed. The new unified `Layouts.app` is structurally full-bleed — `h-screen` outer container with sidebar and `overflow-y-auto` content area satisfies the same constraint.
**Migration**: Replace `<Layouts.full_bleed ...>` with `<Layouts.app ...>` in the roster planner LiveView.

### Requirement: Board columns scroll independently
**Reason**: This is a roster planner internal concern, not a layout concern. It remains a requirement of the roster planner component itself.
**Migration**: No change needed — the planner manages its own column scroll behavior via `overflow-y-auto` on each column container.

### Requirement: Global layout padding is reduced
**Reason**: The new unified layout defines its own content area padding. The `py-6` constraint from this spec is superseded by the new layout's padding.
**Migration**: The new `Layouts.app` content area uses comfortable padding appropriate for the sidebar layout.
