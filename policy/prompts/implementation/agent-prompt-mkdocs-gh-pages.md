# Agent Prompt: Create MkDocs Docs + GitHub Pages (Project Site) via GitHub Actions

## Goal
Create a basic, high-quality documentation site for **this repository** using **Markdown + MkDocs**, published to the repository’s **GitHub Pages project site** using **GitHub Actions** (GitHub Pages `build_type=workflow`). The docs must be easy for humans and coding agents to edit.

## Critical constraint: contribution policy
This prompt **MUST NOT** read, interpret, enforce, or modify anything related to contribution policy (e.g., `CONTRIBUTING.md`, CODEOWNERS, branch protections, PR/commit conventions, templates). That is out of scope.

However, if a contribution policy exists, you **MUST NOT violate it**. Because you are not allowed to evaluate it, you must operate in a way that is least likely to violate typical policies:

- Make all changes on a new branch.
- Do not push to the default branch.
- Open a pull request instead of merging.
- Do not change repo settings unrelated to GitHub Pages.

If any step fails due to policy restrictions, **stop** and report the exact failure (command output + what you attempted), without attempting to bypass restrictions.

---

## Deliverables (files to add/modify)

### 1) MkDocs structure (Markdown-only content)
Create:

- `mkdocs.yml`
- `docs/index.md`
- `docs/getting-started.md`
- `docs/usage.md`
- `docs/architecture.md` (or `docs/design.md`)
- `docs/faq.md` (recommended)
- `docs/assets/` (only if needed for images)

### 2) GitHub Actions workflow for GitHub Pages
Create:

- `.github/workflows/pages.yml`

### 3) Repo hygiene and entrypoints
Create/modify:

- `.gitignore` to ignore `site/` and common MkDocs artifacts
- `README.md` updated to point to the docs site and explain local preview/build commands

---

## Documentation content requirements
Extract meaning from existing project files and create docs that answer:

1. What is this project? (1–2 paragraphs)
2. Who is it for / what problem does it solve?
3. Quickstart (prereqs, install/build/run in the simplest form)
4. Usage (common workflows/commands)
5. Architecture (high-level components, directory layout, data flow)
6. Configuration (key config files, environment variables)
7. Troubleshooting (top 5 likely issues based on what you see)

Write for a new contributor. Keep it concise and skimmable with headings and bullets.

Only include claims you can ground in the repo; if unclear, state assumptions explicitly.

---

## Local workflow to document (default)
Unless the repo already clearly uses another standard, document:

- `python -m venv .venv && source .venv/bin/activate`
- install doc deps (see dependency strategy below)
- `mkdocs serve`
- `mkdocs build --strict`

---

## Dependency strategy (minimal impact)
Prefer a pinned `requirements-docs.txt` at repo root unless there is a strong reason not to:

- `mkdocs==<pin>`

Optional: add a theme only if it materially improves usability and remains lightweight.

Do **not** commit `site/`.

---

## Publishing requirements (GitHub Actions + Pages)
Publishing must use GitHub Actions and deploy with `actions/deploy-pages`. The workflow must:

- run on pushes to the default branch (but you will not push directly; the PR merge will trigger it)
- upload the Pages artifact
- deploy with proper permissions

Baseline workflow (adapt branch name to the repo default branch):

```yaml
name: Deploy MkDocs to GitHub Pages

on:
  push:
    branches: ["<DEFAULT_BRANCH>"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.x"
          cache: "pip"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          if [ -f requirements-docs.txt ]; then
            pip install -r requirements-docs.txt
          else
            pip install mkdocs
          fi

      - name: Build site
        run: mkdocs build --strict

      - name: Setup Pages
        uses: actions/configure-pages@v5

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

## Required operations (must be reproducible)

### 1) Determine repo owner/name and default branch (no policy files)
Use GitHub CLI or git metadata only:

```bash
gh repo view --json name,owner,defaultBranchRef --jq '{name, owner: .owner.login, default: .defaultBranchRef.name}'
```

If `gh` is unavailable, infer default branch from git remote HEAD.

### 2) Create a new branch and commit changes
- Create a new branch (name: `docs/mkdocs-pages` unless that conflicts)
- Commit the added docs/workflow files

### 3) Open a pull request (do NOT merge)
Use `gh pr create` and include a short summary:
- what was added
- how to preview locally
- how Pages is configured

---

## Update repo Pages settings to workflow deployment
You must set GitHub Pages to `build_type=workflow` via GitHub API using `gh api`.

Commands (fill owner/repo from step 1):

```bash
OWNER="<owner>"
REPO="<repo>"

if gh api "/repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "/repos/$OWNER/$REPO/pages" -f build_type=workflow
else
  gh api -X POST "/repos/$OWNER/$REPO/pages" -f build_type=workflow
fi

gh api "/repos/$OWNER/$REPO/pages" --jq '.html_url'
```

If the API call fails (permissions/restrictions), stop and report the exact error output. Do not attempt workarounds.

---

## README update requirements
Update `README.md` to include:

- Docs URL format: `https://<owner>.github.io/<repo>/`
- Local preview commands
- Note: “Docs deploy via GitHub Actions to GitHub Pages”

---

## Acceptance criteria
1. `mkdocs build --strict` succeeds (locally or in CI).
2. `.github/workflows/pages.yml` exists and is valid.
3. Pages is configured for workflow deployment (`build_type=workflow`) **OR** you reported the exact API error preventing it.
4. A PR exists with the docs changes (but you did not merge it).
5. Docs content is grounded in actual repo files; assumptions are explicitly labeled.

---

## Required completion report (agent output)
Provide:

- Files created/modified
- Branch name and commit hash
- PR link
- Pages URL from the API command (or the error output)
- Any assumptions made due to ambiguous project files
