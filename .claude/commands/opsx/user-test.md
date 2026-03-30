---
name: "OPSX: User Test"
description: Browser-test the current active spec using Playwright MCP
category: Workflow
tags: [workflow, testing, browser, experimental]
---

Browser-test the current active spec by driving the live local application at `localhost:4000`.

**Input**: Optionally specify a change name after `/opsx:user-test` (e.g., `/opsx:user-test csv-tag-roundtrip`). If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` and use **AskUserQuestion** to let the user choose

   Show only active (non-archived) changes.

2. **Read specs**

   Read all delta spec files at `openspec/changes/<name>/specs/*/spec.md`.

   Also read the change's `proposal.md` for context on what was built.

   For related capabilities touched by this change, read the corresponding main specs at `openspec/specs/*/spec.md` for smoke-test coverage — use the delta specs and proposal to identify which main capabilities are relevant.

3. **Build the test plan**

   Parse all requirements and scenarios from the delta specs. For each scenario, classify it as one of:
   - **Browser-testable** — has an observable UI outcome (page content, element presence, form behavior, download, error message shown, redirect, etc.)
   - **Not browser-testable** — describes internal return values, Elixir function contracts, transaction behavior, or other non-UI concerns

   For related main specs, identify a minimal set of scenarios for regression smoke testing (focus on happy paths and high-value edge cases that could plausibly break).

   Display the full test plan before proceeding, grouped as:
   - **Delta spec tests** (from this change's specs)
   - **Smoke tests** (regression checks on related capabilities)
   - **Skipped** (non-browser-testable scenarios — list with brief reason)

   Use **AskUserQuestion** to confirm the plan or let the user adjust scope before continuing.

4. **Check credentials**

   Look for a database seeds file in the project (e.g. `priv/repo/seeds.exs` or similar) and read it to find dev credentials. Use the first non-admin member account with group ownership unless the test requires admin access. If no seeds file exists or credentials cannot be determined from it, use **AskUserQuestion** to ask the user.

5. **Check and set up test data**

   Before testing, check whether required data exists in the app by navigating the UI:
   - Navigate to `http://localhost:4000` and log in
   - For each data prerequisite identified from the specs (e.g., tags, players, categories), check if it exists
   - If missing and can be created through the UI, create it and note what was created
   - If missing and creation is unclear, use **AskUserQuestion** to ask the user

   State what data was found and what was created before proceeding to tests.

6. **Run the tests**

   Work through the test plan one item at a time. For each browser-testable scenario:
   - Navigate to the relevant page
   - Perform the required actions
   - Observe and record the outcome
   - Mark as PASS, FAIL, or BLOCKED (if a prerequisite failed)

   Do not stop on failures — continue through all scenarios and collect results.

   **Important:**
   - Only test against `http://localhost:4000` — never access production URLs
   - Actually interact with the browser via Playwright — do not infer or assume results without performing the action
   - Take screenshots on failures to document what was observed

7. **Report results**

   Output a structured report:

   ```
   ## User Test Results: <change-name>

   **Tested:** <date>
   **App:** http://localhost:4000
   **Account used:** <email>

   ### Delta Spec Tests
   | # | Scenario | Result | Notes |
   |---|----------|--------|-------|
   | 1 | ... | PASS | |
   | 2 | ... | FAIL | Expected X, got Y |
   | 3 | ... | BLOCKED | Prerequisite data missing |

   ### Smoke Tests
   | # | Scenario | Result | Notes |
   |---|----------|--------|-------|

   ### Skipped (Not Browser-Testable)
   - Scenario: ... — Reason: internal return value contract
   - Scenario: ... — Reason: transaction rollback behavior

   ---
   **Summary:** N passed, M failed, K blocked, J skipped

   ### Failures Requiring Attention
   <list each FAIL with: scenario name, what was expected, what was observed>
   ```

   If all browser-testable scenarios pass, say so clearly.

**Guardrails**
- Never test against production — only `localhost:4000`
- Always actually use Playwright to interact with the app — never fake or infer test results
- Do not make any code changes — this skill only observes and reports
- If the app is not running, report clearly and stop: "App not reachable at localhost:4000. Is the server running?"
- If login fails, stop and report the credential used and what was observed
- Continue through all tests even when some fail — collect the full picture
- Skipped scenarios must be listed; do not silently omit them
- Do not retest passing scenarios to save time — move on
