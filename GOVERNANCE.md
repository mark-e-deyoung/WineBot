# WineBot Project Governance

This document defines the governance and decision-making model for the WineBot project.

## 1. Participation Model: Invite-Only by Behavior

WineBot follows an "Invite-Only by Behavior" model to maintain high technical standards and ensure alignment with project safety policies.

- **Public Visibility**: The repository is public for visibility, reference, and transparency.
- **Restricted Interaction**: Only approved participants (Maintainers and Approved Collaborators) may open issues or pull requests.
- **Unapproved Contributions**: Issues or PRs from unapproved actors are automatically closed by automation.
- **Path to Participation**: Potential collaborators are identified by maintainers through their technical work in related communities or by invitation.

## 2. Roles

### 2.1. Maintainers
- **Responsibility**: Have write access to the repository, manage releases, and define project direction.
- **Decision Power**: Final authority on technical decisions and policy enforcement.
- **Membership**: Currently limited to the repository owner and designated core contributors.

### 2.2. Approved Collaborators
- **Responsibility**: Contributing code, documentation, or tests.
- **Membership**: Individuals who have been invited to collaborate and added to `.github/approved-actors.yml` or given repository collaborator status.

### 2.3. Automated Agents
- **Responsibility**: Performing automated tasks (linting, testing, state management).
- **Membership**: Identities listed in `.github/approved-actors.yml` with specific permissions.

## 3. Decision-Making Process

- **Technical Decisions**: Maintainers make final technical decisions. Discussion happens in PRs or designated private channels.
- **Policy Changes**: Changes to core policies (Security, Participation, Control) require maintainer consensus and updates to the `policy/` directory.
- **Release Authority**: Only maintainers can trigger the `release` workflow and sign official container images.

## 4. Conflict Resolution

In the event of a disagreement, the final decision rests with the Maintainer(s). If multiple maintainers disagree, the repository owner holds the tie-breaking vote.

## 5. Security & Disclosure

Security is paramount. Vulnerabilities must not be disclosed publicly. All security-sensitive decisions are handled by maintainers through private channels to protect the integrity of the automation stack.
