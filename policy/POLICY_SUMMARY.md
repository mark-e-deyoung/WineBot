# WineBot Policy Summary

This file summarizes the main policies currently used by WineBot and where each is defined or enforced.

## Enforced Policies

### 1. Invite-Only Participation (Public Repo, Collaborator + Approved Automation Only)
- Issues and PRs from unapproved actors are automatically:
  1. labeled `unapproved`,
  2. commented with an invite-only notice,
  3. closed.
- Approved actors:
  - repository collaborators
  - identities listed in `.github/approved-actors.yml`
- Additional fork protection:
  - PRs from forks are rejected unless the author is a repository collaborator.
- Enforcement:
  - `.github/workflows/approved-issues-only.yml`
  - `.github/workflows/approved-prs-only.yml`
- Contributor-facing statement:
  - `CONTRIBUTING.md`

### 2. Interactive Control / Non-Preemption Policy
- In interactive sessions, user control takes priority.
- Agent actions are blocked unless agent control is explicitly granted and valid.
- User activity and STOP_NOW revoke agent control.
- Enforcement:
  - `api/core/broker.py`
- Policy design reference:
  - `policy/WineBot-Interactive-Control-Policy.md`

### 3. API Access Token Policy
- If `API_TOKEN` is configured, API calls must include `X-API-Key`.
- Enforcement:
  - `api/server.py`

### 4. Release Security and Guardrail Policy
- Release workflow includes security and safety controls (tag validation, release guard checks, scanning, signing, publish verification).
- Enforcement:
  - `.github/workflows/release.yml`

## Documented Process/Standards Policies

### 5. Dependency and Version Pinning Policy
- Requires pinned versions/digests for reproducibility and security.
- Reference:
  - `policy/dependency-policy.md`

### 6. Security Hardening Policy Notes
- Security hardening guidance and backlog:
  - `policy/security_hardening.md`

### 7. Security Disclosure Policy
- Security issues should not be publicly disclosed in issues/PRs.
- Reference:
  - `CONTRIBUTING.md`

### 8. Licensing Policy
- Project license terms are defined in:
  - `LICENSE`

## Policy Prompts and Draft Artifacts

The following files are policy-related artifacts/prompts and are not runtime enforcement mechanisms by themselves:
- `policy/prompts/implementation/agent-prompt-mkdocs-gh-pages.md`
- `policy/prompts/implementation/invite_only_policy_agent_prompt_whitelist.md`
- `policy/prompts/implementation/winebot-build-intent-policy-agent-prompt.md`

## Root-Level Convention Files

These files are policy-adjacent and intentionally remain at repository root for ecosystem/tooling conventions:
- `CONTRIBUTING.md`
- `LICENSE`
