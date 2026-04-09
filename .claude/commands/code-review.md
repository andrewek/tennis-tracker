---
name: "Code Review"
description: Review changed code between current branch and main, producing a structured findings report
category: Workflow
tags: [review, quality]
---

Perform a code review of all changes on the current branch relative to `main`. Produce a structured findings report. Do NOT fix anything — output findings only.

## Steps

### 1. Get the diff

```bash
git diff main...HEAD --name-only
git diff main...HEAD --stat
```

Then get the full diff for context:

```bash
git diff main...HEAD
```

Also check for untracked files that may be part of this change:

```bash
git status --short
```

### 2. Read relevant project conventions

Read `CLAUDE.md`, `AGENTS.md` (if present), and `.claude/skills/liveview-testing/SKILL.md` to ground your review in the project's established conventions. Pay particular attention to:
- LiveView conventions (streams, forms, navigation)
- Ash conventions (domain calls, policies, multitenancy, query patterns)
- Testing conventions
- Authorization patterns

### 3. Read each changed file in full

For every file that appears in the diff, read the current version in full — don't rely only on the diff lines. You need context to spot issues.

Also read any test files corresponding to changed source files, and vice versa.

### 4. Check for issues across these categories

**Convention violations** — things that diverge from what's established in `CLAUDE.md`, `AGENTS.md`, or consistent patterns in the existing codebase:
- Ash: raw Ecto queries instead of domain functions, missing `tenant:` or `actor:` on Tennis domain calls, `Enum.filter/sort` on Ash data instead of DB-level filtering, wrong policy check patterns (`FilterCheck` vs `SimpleCheck`), missing `bypass` policy on tenant-scoped resources
- LiveView: plain lists assigned instead of streams, `@changeset` accessed in templates, `live_redirect` instead of `push_navigate`/`<.link navigate>`, missing `<Layouts.app>` wrapper, wrong form patterns
- Authorization: manual role checks instead of `Ash.can?`, buttons/links rendered for actions the user can't perform, unauthorized form URLs not redirected in `mount/handle_params`
- General Elixir: `is_thing` predicate naming (should end in `?`), `String.to_atom/1` on user input, indexed list access with brackets, early-return patterns

**Dead code, over-defensive coding, unnecessary complexity:**
- Unused variables, functions, or clauses that are never reached
- Guards or error handling for scenarios that provably cannot occur
- Feature flags, backwards-compatibility shims, or `_unused` renames for removed code
- `Process.sleep` in tests
- Abstracted helpers introduced for a single use

**Duplication and missed abstractions:**
- Repeated logic that could be extracted (but only if it's used 3+ times or the duplication is clearly harmful)
- Multiple code paths doing the same thing slightly differently

**Naming and readability:**
- Unclear variable or function names
- Function names that don't reflect what they do
- Overly abbreviated names where the full word is clearer
- Missing clarity where the logic isn't self-evident (complex Ash expressions, non-obvious policy logic)

**Test quality:**
- Tests that assert on raw HTML strings (should use `has_element?/2` or `element/2`)
- Tests using `Process.sleep/1` (should use `start_supervised!/1` or proper async patterns)
- Tests that don't actually exercise what their description says they test
- Tests that contradict the currently open project specifications (check `openspec/changes/` if present)
- Missing test coverage for critical paths (auth checks, policy enforcement, error states)
- Test setup that is overly broad or sets up data that's never used in assertions

**Other issues:**
- Security concerns (missing authorization checks, unvalidated user input reaching DB queries)
- N+1 query patterns (loading relationships in a loop, missing `load:` in Ash queries)
- Hardcoded values that should be configurable or come from the record

### 5. Produce the report

Format your findings as follows. If a category has no findings, omit it entirely. Be specific: include file paths and line numbers for every finding.

---

## Code Review: `<branch-name>` vs `main`

**Files reviewed:** N files changed, N additions, N deletions

---

### Convention Violations

> Issues where the code diverges from established project patterns.

- **`path/to/file.ex:42`** — Description of the issue and what the convention requires instead.

---

### Dead Code / Over-defensive Coding

> Unreachable branches, unnecessary guards, unused abstractions.

- **`path/to/file.ex:17`** — Description.

---

### Duplication

> Repeated logic where a consolidation would be worth making.

- **`path/to/file.ex:55` and `path/to/other.ex:23`** — Description of what's duplicated.

---

### Naming and Readability

> Unclear names or logic that's hard to follow without comments.

- **`path/to/file.ex:88`** — Description.

---

### Test Quality

> Tests that don't cover what they claim, contradict specs, or have structural issues.

- **`test/path/to/test.exs:34`** — Description.

---

### Other Issues

> Security, performance, or correctness issues that don't fit above.

- **`path/to/file.ex:101`** — Description.

---

### Summary

An itemized list of all findings across all categories, sorted by severity (most critical first). Each item should reference its category and include the file/line. Follow with one sentence on overall quality and anything that looks intentional but surprising.

Example format:

- **[Convention Violation — Critical]** `path/to/file.ex:42` — Brief description.
- **[Test Quality — Major]** `test/path/to/test.exs:34` — Brief description.
- **[Dead Code — Minor]** `path/to/file.ex:17` — Brief description.

---

## Guardrails

- **Do NOT make any edits.** Output findings only. If you notice something fixable, note it in the report and stop.
- If a file is very large, focus on the diff lines plus surrounding context — don't get lost in unrelated code.
- Don't flag stylistic preferences not established in project conventions. Stick to the criteria above.
- If you can't tell whether something is intentional or a bug, note the ambiguity rather than assuming.
- Omit categories that have no findings — don't pad the report.
