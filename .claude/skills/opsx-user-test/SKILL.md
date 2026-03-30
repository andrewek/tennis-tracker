---
name: opsx-user-test
description: Browser-test the current active spec using Playwright MCP. Navigates localhost:4000, exercises each browser-testable scenario from the change's delta specs, runs smoke tests on related capabilities, and produces a structured pass/fail report. Never makes code changes.
license: MIT
compatibility: Requires openspec CLI and Playwright MCP.
metadata:
  author: local
  version: "1.0"
---

Browser-test the current active spec by driving the live local application at `http://localhost:4000` using Playwright MCP.

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Auto-select if exactly one active change exists
   - If ambiguous, run `openspec list --json` and use **AskUserQuestion** to let the user choose

   Announce: "Testing change: <name>"

2. **Read specs**

   Read all delta spec files at `openspec/changes/<name>/specs/*/spec.md`.
   Read `openspec/changes/<name>/proposal.md` for context.

   For related capabilities, identify which main specs at `openspec/specs/*/spec.md` are relevant for regression smoke testing (use the delta specs and proposal to determine this).

3. **Build the test plan**

   Parse all requirements and scenarios. Classify each as:
   - **Browser-testable** — observable UI outcome (page content, element presence, form behavior, file download, error/success message, redirect, visual state)
   - **Not browser-testable** — internal return value contracts, Elixir function signatures, transaction rollback mechanics, non-UI data shape assertions

   For related main specs, pick a minimal set of scenarios for regression smoke testing (happy paths + high-value edge cases).

   Display the full test plan grouped as:
   - **Delta spec tests** (from this change's specs)
   - **Smoke tests** (regression checks on related capabilities)
   - **Skipped** (non-browser-testable — list each with reason)

   Use **AskUserQuestion** to confirm or let the user adjust scope.

4. **Check credentials**

   Look for a database seeds file in the project (e.g. `priv/repo/seeds.exs` or similar) and read it to find dev credentials. Default to the first non-admin member account with group owner access. Use admin only when the scenario explicitly requires it. If no seeds file exists or credentials cannot be determined from it, use **AskUserQuestion**.

5. **Check and set up test data**

   Navigate to `http://localhost:4000` and log in. Verify the app is reachable — if not, stop with: "App not reachable at localhost:4000. Is the server running?"

   For each data prerequisite identified from the specs (tags, categories, players, etc.):
   - Check if it exists by navigating the relevant UI
   - If missing and creatable through the UI, create it and note what was created
   - If missing and unclear how to create it, use **AskUserQuestion**

   State what data was found vs. created before proceeding.

6. **Run the tests**

   Work through the test plan one scenario at a time. For each browser-testable scenario:
   - Navigate to the relevant page
   - Perform the required interactions (clicks, form fills, file uploads/downloads, etc.)
   - Observe the outcome
   - Mark as **PASS**, **FAIL**, or **BLOCKED** (prerequisite failed)

   On failure, take a screenshot and note what was expected vs. observed. Do not stop — continue through all scenarios.

   **Always use Playwright to actually interact with the app. Never infer or assume results.**
   **Only test against `http://localhost:4000` — never follow external or production URLs.**

7. **Report results**

   Output:

   ```
   ## User Test Results: <change-name>

   **Tested:** <date>
   **App:** http://localhost:4000
   **Account used:** <email>
   **Data set up:** <summary of any data created>

   ### Delta Spec Tests
   | # | Requirement | Scenario | Result | Notes |
   |---|-------------|----------|--------|-------|
   | 1 | ... | ... | PASS | |
   | 2 | ... | ... | FAIL | Expected X, got Y |

   ### Smoke Tests
   | # | Capability | Scenario | Result | Notes |
   |---|------------|----------|--------|-------|

   ### Skipped (Not Browser-Testable)
   - **<Scenario>** — <reason>

   ---
   **Summary:** N passed · M failed · K blocked · J skipped

   ### Failures Requiring Attention
   *(empty if all passed)*

   **<Scenario name>**
   - Expected: <what the spec requires>
   - Observed: <what actually happened>
   ```

**Guardrails**
- Only test `http://localhost:4000` — never production
- Always use Playwright to interact — never fake or skip tests
- Never make code changes — observe and report only
- If the app is unreachable, stop immediately and report clearly
- If login fails, stop and report the credential used and what was observed
- Run all tests even when some fail — collect the full picture before reporting
- List every skipped scenario — do not silently omit
- Do not rerun passing tests to save time
