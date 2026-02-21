# Contributing

## Participation Policy
This repository is public for visibility and reference, but participation is invite-only.

Only approved participants may open issues or pull requests:
- repository collaborators, and
- approved automation identities maintained in `.github/approved-actors.yml`.

Fork-based pull requests from non-collaborators are not accepted, even for approved automation identities.

Issues and pull requests opened by unapproved actors are automatically labeled `unapproved`, receive an explanatory comment, and are closed.

## Guidance for Collaborators

### Issues
- Provide clear reproduction steps.
- Include environment details (OS, runtime/container version, relevant configuration).
- Attach logs, traces, or screenshots when relevant.
- State expected behavior and actual behavior.

### Pull Requests
- Keep changes focused and small.
- Include tests for behavior changes.
- Update documentation when behavior or interfaces change.
- Ensure CI and diagnostics relevant to your change pass.

## Security
Do not disclose vulnerabilities publicly in issues or pull requests. Report security concerns through private channels.

## Development Policies

### Unified Lifecycle Management
WineBot uses a unified entrypoint for development tasks. Use the `scripts/wb` tool to ensure consistency:
- `scripts/wb bootstrap`: Initialize the environment.
- `scripts/wb lint`: Run Ruff and Mypy.
- `scripts/wb test`: Run unit tests.
- `scripts/wb smoke-test`: Run full diagnostic suite.
- `scripts/wb vuln`: Run vulnerability scans.

### Containerized Tooling
WineBot enforces a strict policy of containerized development. Do not run tests or linters on your host machine.
- Reference: `policy/containerized-tooling-policy.md`
- Usage: `scripts/wb smoke-test`

