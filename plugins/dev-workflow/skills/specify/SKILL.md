---
name: specify
description: You are given a new feature idea or a change request for an existing feature. Write down the comprehensive product requirements.
disable-model-invocation: true
metadata:
  internal: true
---

## Writing style

Write short sentences, get rid of extra words. Avoid putting multiple thoughts in one sentence. Prefer the active voice, subject first (readers comprehend “the boy hit the ball” quicker than “the ball was hit by the boy”).

## Steps

1. Start a worktree following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`, with a slug derived from the feature description.

2. Read `docs/product-overview.md` and `docs/domain-model.md`, understand the high-level idea of the product and the feature.

3. Interview the user relentlessly until you reach a shared complete understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

   Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

   Format a round like so:

   ```
   ❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

   ➡️ <your recommended answer>

   ---

   ❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

   ➡️ <your recommended answer>
   ```

   Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

   Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (the repo, the docs, the running product), dispatch a subagent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the subagent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

   This step is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Then go straight to writing the requirements in step 5. Don't summarise the decisions for approval first: the user reviews the written plan and asks for changes there.
   
4. Sharpen the product's language as you understand the problem. `docs/domain-model.md` is the glossary.

   - **Challenge terms against the glossary.** When the user's word conflicts with the language already in the overview, call it out immediately: "the overview defines 'library' as X, but you seem to mean Y. Which is it?"
   - **Sharpen fuzzy language.** When a term is vague or overloaded, propose a precise canonical one: "you're saying 'file': do you mean the item on disk or the row the user sees? Those are different things."
   - **Discuss concrete scenarios.** Invent the edge case and force the user to be precise about where one concept ends and the next begins.
   - **Cross-reference with code.** When the user states how something works today, check whether the code agrees, and surface the contradiction if it does not.
   - **Offer to record product decisions sparingly.** A decision that outlives this feature, that a future reader would wonder about, belongs in the overview: offer it there and move on. Architecture decisions are the `plan` and `architect` skills' to offer; leave them.

5. Write the product requirements using the template below, at `plans/<NNN-slug>/plan.md`. One feature per plan: a coherent capability a user would recognise, complete enough to demo on its own. Write in product language only. Every section is required; write "None" rather than deleting a heading.

6. Dispatch **one** `prd-reviewer` subagent from this plugin, never reviewing the draft yourself. Pass it **only** the path to `plans/<NNN-slug>/plan.md` and the path to `docs/product-overview.md`. Then go through its findings one by one and decide which to accept. Dispatch a **generic** subagent to apply the accepted findings, and wait for it to finish. Never end your turn while it runs. Check that the plan holds each change. Then create `plans/<NNN-slug>/development-logs.md` from `${CLAUDE_PLUGIN_ROOT}/references/development-logs-template.md` and record the applied changes under Specify.

7. Once the PRD is finalized, report to the user the status, the path to the plan document, the worktree path, and that the next step is `/architect` for a new feature or a significant change, or `/plan` for a less complex feature or a small to medium change. When `/do` is running this skill, leave out the next step: `/do` asks the user to confirm and then continues on its own.

<product-requirements-template>

# Plan: <feature name>

## Problem statement

The problem that the user is facing, from the user's perspective, and what is bad about it today.

## Solution

The solution to the problem, from the user's perspective.

## Requirements

What the feature does, in terms anyone could check — not how it is built. Requirements are statements of behaviour; scenarios are concrete examples that prove them.

This section is a behaviour contract, not an implementation plan. Good content:

- Observable behaviour users or downstream systems rely on
- Inputs, outputs, and error conditions
- External constraints (security, privacy, reliability, compatibility)
- Scenarios that can be tested or explicitly validated

Keep out of it:

- Internal class or function names
- Library or framework choices
- Step-by-step implementation details

Quick test: if the implementation can change without changing externally visible behaviour, it does not belong here. Keep the _how_ — the queue, the library, the table schema — for `/plan` or `/architect`. Behaviour and implementation mixed into one requirement stops being testable and goes stale the moment the code changes.

Format:

- Each requirement: `### R<N>. <name>` followed by its description. Number them `R1`, `R2`, … in one continuous sequence, so `/plan`, `/architect` and the reviewers cite them by ID.
- Use MUST/SHALL for normative requirements.
- Each scenario: `#### Scenario: <name>` with GIVEN/WHEN/THEN bullets (GIVEN only where the starting state matters).
- Every requirement has at least one scenario.

<requirements-example>
### R1. Account rows show a current balance
Each account row MUST show that account's current balance in the account's own currency.

#### Scenario: Multi-currency accounts
- **GIVEN** a customer holding a EUR account and a USD account
- **WHEN** they open the account list
- **THEN** each row shows its own balance in its own currency

#### Scenario: Balance fails to load
- **WHEN** the balance request for an account fails
- **THEN** that row shows a retry affordance and the other rows still show their balances
</requirements-example>

**A good requirement** is one behaviour, stated so plainly you could hand it to someone else to test.

- **One statement, one MUST/SHALL.** A requirement with three "and also" clauses is really three requirements. Split them.
- **Observable.** Someone outside the code can tell whether it holds. "The system MUST show an error banner when the upload exceeds 10 MB" is observable; "the system MUST handle large uploads gracefully" is not.
- **The right strength.** MUST/SHALL is a hard requirement, non-negotiable. SHOULD is a strong recommendation, with room for a justified exception. MAY is genuinely optional. Reach for MUST/SHALL by default; use SHOULD only when you truly mean "unless there's a good reason not to."

The test for a requirement: could a tester who has never seen the code tell whether it passed? If not, it needs sharpening.

**A good scenario** is where a requirement earns its keep — a concrete GIVEN/WHEN/THEN that could become an automated test.

- **It exercises its requirement.** A scenario that restates the requirement in other words tests nothing. Make it a specific situation with a specific outcome.
- **Cover the cases that matter, not just the happy path.** The valid login is easy. The empty input, the expired token, the second click, the thing that goes wrong — those are where bugs live, and where a scenario is worth the most.
- **Name the case in the title.** "Scenario: Rejects an expired token" tells a reviewer what is covered at a glance; "Scenario: Test 2" doesn't.

Requirements should be testable — each scenario is a potential test case, and `/plan` or `/architect` builds its test scenarios from them.

## Non-goals

What a reader would reasonably assume is in this feature and is not, each with the reason.

</product-requirements-template>
