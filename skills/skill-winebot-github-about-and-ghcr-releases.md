# skill: winebot-github-about-and-ghcr-releases

This skill guides Codex to (1) update the **WineBot** repository “About” section using the GitHub CLI (`gh repo edit`), and (2) treat GitHub **Releases** as *container-backed* releases by publishing images to **GitHub Container Registry (GHCR)** and embedding pull/run instructions + package links into release notes.

Repository: **mark-e-deyoung/WineBot**  
Default image: **ghcr.io/mark-e-deyoung/winebot** (lowercase is recommended for GHCR/package URLs)

---

## When to use

Use this skill when asked to:
- update the repo **About** box (description / website / topics)
- ensure the repo shows **Packages** by pushing a container to GHCR
- write or update **Release notes** to include a container link and “how to pull/run” instructions
- align tags between git releases and container tags (e.g., `v0.1`, `v0.1.0`)

---

## Required tools / assumptions

- `gh` installed and authenticated (`gh auth status` succeeds)
- `git` available
- Docker engine (or equivalent) available if building/pushing locally; otherwise use GitHub Actions to build/push
- **Never** print or paste secrets (tokens, passwords). Use environment variables / GitHub Actions secrets.

---

## Operating rules

1. **Prefer Packages for distribution**: GHCR is authoritative for container delivery; Releases are for changelogs + instructions.
2. **Homepage (“Website”) should be useful**:
   - If GHCR package exists, point homepage to the GHCR package page.
   - Otherwise, point homepage to the repo README.
3. **Topics**: single-token topics only (no spaces); use hyphens where needed.
4. **Tag strategy**:
   - Use a fixed version tag matching the release (e.g., `v0.1`)
   - Optionally publish `latest` as a moving tag (only if intended)
5. Validate each step with `gh repo view`, `gh release view`, and a `docker pull` sanity check.

---

## Step A — Identify repo and set canonical variables

```bash
# Works inside the repo directory
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# For WineBot, enforce expected repo
test "$REPO" = "mark-e-deyoung/WineBot" || echo "Warning: current repo is $REPO"

OWNER="mark-e-deyoung"
IMAGE_NAME="winebot"
IMAGE="ghcr.io/${OWNER}/${IMAGE_NAME}"
```

---

## Step B — Update the “About” section using `gh repo edit`

Recommended WineBot About settings:

- Description: short, clear purpose
- Homepage: GHCR package page (once published), else repo URL
- Topics: wine, xvfb, automation, containers, ghcr, github-actions, windows, ci

```bash
REPO="mark-e-deyoung/WineBot"

# Use GHCR package page as homepage once the package exists:
HOMEPAGE="https://github.com/users/mark-e-deyoung/packages/container/winebot"

# If GHCR package doesn't exist yet, use the repo URL:
# HOMEPAGE="https://github.com/mark-e-deyoung/WineBot"

gh repo edit "$REPO"   --description "WineBot: containerized Windows automation sandbox (Wine + Xvfb) with repeatable tool installs and CI-built images."   --homepage "$HOMEPAGE"   --add-topic wine   --add-topic xvfb   --add-topic windows   --add-topic automation   --add-topic docker   --add-topic ghcr   --add-topic github-actions   --add-topic ci
```

### Validate About
```bash
gh repo view "$REPO" --json description,homepageUrl,repositoryTopics   -q '{description, homepageUrl, topics: [.repositoryTopics[].name]}'
```

---

## Step C — Publish at least one container image to GHCR

### Option 1: Publish locally (manual)

> Only do this if Docker is available locally and you have a token with permission to push packages.
> Do **not** echo tokens to the console; prefer `--password-stdin`.

```bash
OWNER="mark-e-deyoung"
IMAGE_NAME="winebot"
IMAGE="ghcr.io/${OWNER}/${IMAGE_NAME}"
TAG="v0.1"

# Build
docker build -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" .

# Login (requires a token with packages:write, stored in $GITHUB_TOKEN)
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$OWNER" --password-stdin

# Push tags
docker push "${IMAGE}:${TAG}"
docker push "${IMAGE}:latest"
```

### Option 2: Publish via GitHub Actions (preferred)

Ensure your workflow builds and pushes to GHCR on tags.
Use:
- `docker/login-action` with `GITHUB_TOKEN`
- `docker/build-push-action` with `push: true`
- tags: `${{ github.ref_name }}` and `latest` (optional)

Codex should modify/verify `.github/workflows/*` accordingly and ensure the job has:
- `permissions: packages: write`
- `permissions: contents: read` (or appropriate)

### Validate GHCR image exists

```bash
docker pull "ghcr.io/mark-e-deyoung/winebot:v0.1"
```

Once pushed, the **Packages** area should populate, and the package page should exist at:
- https://github.com/users/mark-e-deyoung/packages/container/winebot

---

## Step D — Add container instructions + links to GitHub Release notes

Releases should explain **how to get the container**.

### Edit existing release notes

```bash
VERSION="v0.1"
OWNER="mark-e-deyoung"
IMAGE_NAME="winebot"
IMAGE="ghcr.io/${OWNER}/${IMAGE_NAME}"
PKG_URL="https://github.com/users/${OWNER}/packages/container/${IMAGE_NAME}"

cat > /tmp/release-notes.md <<EOF
## Container image (GHCR)

This release is published as a container image on GitHub Container Registry (GHCR).

Package page:
${PKG_URL}

Pull:
\`\`\`bash
docker pull ${IMAGE}:${VERSION}
\`\`\`

Run (example):
\`\`\`bash
docker run --rm -it ${IMAGE}:${VERSION}
\`\`\`

Also available as \`:latest\` (moving tag), if you prefer it.
EOF

gh release edit "$VERSION" --notes-file /tmp/release-notes.md
```

### Create a release (if needed)

```bash
VERSION="v0.1"
gh release create "$VERSION" --title "$VERSION" --notes-file /tmp/release-notes.md
```

### Validate release body

```bash
gh release view "v0.1" --json tagName,name,body -q '{tagName,name,body}'
```

---

## Step E — Ensure repo “Website” points to the container package (optional but recommended)

After the package exists, set the About homepage to the package page:

```bash
gh repo edit "mark-e-deyoung/WineBot"   --homepage "https://github.com/users/mark-e-deyoung/packages/container/winebot"
```

---

## Common pitfalls and fixes

- **Packages not showing**: You must push at least one image to GHCR under the owner/org.
- **Wrong GHCR name/case**: GHCR/package URLs are best kept lowercase (`winebot`).
- **Release tag mismatch**: If release tag is `v0.1`, publish image tag `v0.1` too.
- **Missing permissions in Actions**: set workflow `permissions: packages: write`.
- **Private package visibility**: if you expect public pulls, ensure package visibility is public.

---

## Output checklist (Codex must produce)

- [ ] `gh repo edit` executed to set WineBot description/homepage/topics
- [ ] At least one GHCR image pushed: `ghcr.io/mark-e-deyoung/winebot:<tag>`
- [ ] Release notes updated/created with:
  - [ ] package page URL
  - [ ] `docker pull ...:<tag>`
  - [ ] minimal `docker run` example
  - [ ] mention of `latest` (only if published)
- [ ] Validation commands run and outputs checked
