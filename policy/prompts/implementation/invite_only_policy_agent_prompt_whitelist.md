# Agent Prompt --- Enforce Invite-Only Contribution Policy (Whitelist + Fork Protection)

You are a coding agent working inside an **existing GitHub repository**.
Your task is to implement an **invite-only participation policy** using
GitHub Actions automation with a repository-maintained whitelist.

This repository is public for visibility and reference, but contribution
is restricted to explicitly approved collaborators and a controlled
whitelist of trusted automation identities.

------------------------------------------------------------------------

## Policy (Non-Negotiable)

The repository is public. Participation is **invite-only** and enforced
automatically.

Approved actors are:

1.  **Repository collaborators** (primary approval mechanism)
2.  **Whitelisted identities** maintained in the repository (for trusted
    agents)

All other actors are unapproved.

### Critical Fork Protection Rule

Even if an actor is whitelisted:

> **Pull requests originating from forks must be rejected unless the
> author is a repository collaborator.**

This prevents external fork-based injection, even from trusted
automation identities.

------------------------------------------------------------------------

## Whitelist Model

Create a whitelist file in the repository:

`.github/approved-actors.yml`

Example structure:

``` yaml
users:
  - google-jules-bot
  - codex-bot
  - codex-cli
  - gemini-cli
```

This whitelist allows trusted automation identities to interact **only
when operating inside the base repository**, not from forks.

Collaborators are always approved regardless of whitelist status.

------------------------------------------------------------------------

## Enforcement Rules

### Issues

When an issue is opened or reopened:

Approved if:

-   opener is a collaborator, OR
-   opener is listed in the whitelist

Otherwise:

1.  Ensure label `unapproved` exists

2.  Apply label

3.  Comment:

    > "This repository is invite-only. Issues from unapproved actors are
    > automatically closed."

4.  Close issue

------------------------------------------------------------------------

### Pull Requests

When a PR is opened or reopened:

Approved if:

-   author is a collaborator, OR
-   author is whitelisted **AND** PR originates from the same repository
    (not a fork)

Otherwise:

1.  Ensure label `unapproved` exists

2.  Apply label

3.  Comment:

    > "This repository is invite-only. Pull requests from unapproved
    > actors or forks are automatically closed."

4.  Close PR

------------------------------------------------------------------------

## Scope

Modify only repository files.

Do not require GitHub UI configuration beyond noting:

Settings → Actions → General → Workflow permissions → **Read and write**

PR enforcement must use:

-   `pull_request_target`
-   Metadata-only operations
-   No checkout
-   No execution of untrusted code

------------------------------------------------------------------------

## Files to Create

### 1) `.github/approved-actors.yml`

Whitelist file defining trusted automation identities.

Must be parsed by workflows at runtime.

------------------------------------------------------------------------

### 2) `.github/workflows/approved-issues-only.yml`

Trigger:

    issues: opened, reopened

Behavior:

-   Read issue opener
-   Load whitelist file
-   Check collaborator status via:

```{=html}
<!-- -->
```
    GET /repos/{owner}/{repo}/collaborators/{username}

-   Apply enforcement rules above

Permissions:

    issues: write
    contents: read

------------------------------------------------------------------------

### 3) `.github/workflows/approved-prs-only.yml`

Trigger:

    pull_request_target: opened, reopened

Behavior:

-   Read PR author
-   Detect fork status via repo comparison
-   Load whitelist
-   Apply collaborator + fork rules
-   Label/comment/close if unapproved

Security requirements:

-   DO NOT checkout PR code
-   DO NOT execute untrusted code

Permissions:

    pull-requests: write
    issues: write
    contents: read

------------------------------------------------------------------------

### 4) `CONTRIBUTING.md`

Must state:

-   Repository is invite-only
-   Only collaborators and approved automation may participate
-   Fork-based PRs from non-collaborators are rejected
-   Submissions from unapproved actors are automatically closed
-   No instructions for requesting access

Include collaborator guidance and a brief private security disclosure
note.

------------------------------------------------------------------------

## Implementation Requirements

-   Use `actions/github-script@v7`
-   Load whitelist via repository file read
-   Label creation must be idempotent
-   Workflows must be fork-safe
-   No untrusted code execution

Optional:

-   Store label/comment text in environment variables

------------------------------------------------------------------------

## Deliverable

Create all files in the repository working tree.

Provide a summary describing:

-   Files created
-   Enforcement logic
-   Reminder to enable Actions write permissions

Do not modify unrelated files.

------------------------------------------------------------------------

## Success Criteria

Automation must enforce:

✔ Collaborator actions allowed\
✔ Whitelisted automation allowed (same-repo only)\
✔ Fork-based PRs blocked unless collaborator\
✔ All other submissions labeled + closed

No manual moderation required.
