# Agent Prompt: Implement DEV/TEST/REL Build-Intent Policy in WineBot
Repo: https://github.com/mark-e-deyoung/WineBot  
Version: 1.0  
Last updated: 2026-02-09

## Mission
Implement a **Build Intent Policy** for WineBot with three intents:

- **DEV**: interactive development (including agent-assisted development)
- **TEST**: local + CI validation
- **REL**: end-user release/deployment

WineBot is shipped primarily as a **Docker image + Docker Compose profiles**. Implement this policy via:

- Docker build args / build stages
- image labels/metadata
- Compose wiring (profiles remain runtime behavior)
- runtime gating (only for REL-safe toggles)
- repository checks/tests and CI gates

This work must be done in the existing repository without breaking current usage patterns.

---

## Key Constraints and Guardrails

1. **Do not break existing core workflows**
   - Compose profiles: `--profile headless` and `--profile interactive`
   - Existing entrypoint behavior (Xvfb bring-up, permissions/UID mapping)
   - Sessions + artifacts layout under `/artifacts/sessions/...`
   - Existing exported `WINEBOT_SESSION_DIR` and artifact retention behavior

2. **API/CLI are product surface, not “debug endpoints”**
   - The policy requirement “no debug endpoints in REL” must be interpreted as:
     - **Prohibit**: hidden/admin backdoors, test-only routes, insecure inspector endpoints, anything bypassing auth
     - **Allow**: documented API endpoints and `scripts/winebotctl` (they are core functionality)

3. **Compile/package-time guarantees**
   - Anything prohibited in REL must be **compiled out or packaged out**
   - It must **not** be possible to enable prohibited features in REL via env vars/config

4. **REL must include Support Diagnostics**
   - End user must be able to generate a **single consolidated Support Bundle archive**
   - Bundle generation must be:
     - user-initiated
     - local-only by default
     - bounded (size/time)
     - redacted

5. **Idempotent behavior**
   - Re-running build/test/bundle commands should be safe and deterministic
   - Avoid destructive operations without explicit user intent

---

## Step 0 — Repo Reconnaissance (do first)
Inspect and summarize:

- Docker build layout under `docker/`
- Compose file(s) under `compose/` (notably `compose/docker-compose.yml`)
- Scripts under `scripts/`, especially:
  - `scripts/install-app.sh`
  - `scripts/run-app.sh`
  - `scripts/winebotctl`
- Tests under `tests/`
- Policy docs:
  - `AGENTS.md`
  - `WineBot-Interactive-Control-Policy.md`
- Current CI under `.github/workflows`

Deliverable:
- Add a short section to `docs/build-intents.md` titled **“Current WineBot State (Recon)”** describing:
  - how builds are produced today
  - how compose profiles are used today
  - where logs/artifacts live today
  - what you will treat as “test-only” vs “runtime”

---

## Step 1 — Canonical Build Intent Plumbing
Implement a single source of truth:

- Canonical variable: `BUILD_INTENT` ∈ `{dev, test, rel}`

For Docker builds:
- Add `ARG BUILD_INTENT=rel` in the main Dockerfile
- Set an image label:
  - `LABEL io.winebot.build_intent=$BUILD_INTENT`
- Add/maintain OCI labels if the project already uses them:
  - `org.opencontainers.image.revision`
  - `org.opencontainers.image.created`
  - `org.opencontainers.image.source`

Runtime:
- Ensure `BUILD_INTENT` is available inside the container as an environment variable
- This is only used for REL-safe defaults (e.g., log level caps), not to enable forbidden features

---

## Step 2 — Define Capability Classes (WineBot-specific)
Create `docs/build-intents.md` (or add to existing docs) mapping WineBot capabilities into these classes:

1. **Deep Diagnostics (DEV only)**
   - extra troubleshooting packages (strace/lsof/editors)
   - high-volume tracing defaults
   - developer-only “inspect” tools, if any

2. **Test Hooks (TEST only; optionally DEV)**
   - smoke test harnesses under `tests/`
   - CI-only helpers (coverage outputs, fixtures)
   - any fault injection or deterministic “test mode” toggles

3. **Support Diagnostics (DEV/TEST/REL)**
   - bounded logs + traces
   - build/version metadata
   - redacted config/env snapshots
   - crash/minidumps if present (opt-in where sensitive)
   - **support bundle generation**

4. **Core health signals (optional)**
   - low overhead counters/health endpoints that are part of supported operations
   - must not include sensitive payloads

Explicitly classify:
- Wine debug channels / winedbg helpers
- any input recorder/tracing tooling
- VNC/noVNC access (product UX, allowed in REL but must be secured/documented)
- session artifact collection

Important:
- Do **not** equate `interactive` compose profile with DEV intent.
- Interactive must remain available in REL as a supported user workflow.

---

## Step 3 — Implement Image-Level Staging
Update the Docker build to create intent-specific outputs.

Preferred approach:
- A **single Dockerfile** with build stages and conditional steps keyed by `BUILD_INTENT`
- Produces tags/targets:
  - `winebot:dev`
  - `winebot:test`
  - `winebot:rel` (and `:latest` if already used)

### DEV image requirements
- May include additional dev utilities and heavier diagnostics
- Defaults may be more verbose
- Must remain easy to use locally

### TEST image requirements
- Includes test harnesses and CI-only utilities
- Deterministic artifact output locations for CI
- May include coverage tooling only if used

### REL image requirements
- Excludes test harnesses and dev-only tooling
- Keeps only runtime necessities + Support Diagnostics + Support Bundle generator
- Must not include “test-only” scripts/binaries/routes

Deliverable:
- Document which packages/files are present in each intent in `docs/build-intents.md`

---

## Step 4 — Compose Integration
Update compose so builds are reproducible and intent-aware:

- Forward `BUILD_INTENT` as a build-arg
- Optionally set container env `BUILD_INTENT` to match

Must preserve:
- `--profile headless`
- `--profile interactive`

Document examples in README/docs:
- `BUILD_INTENT=dev docker compose ... up --build`
- `BUILD_INTENT=test docker compose ... up --build`
- `BUILD_INTENT=rel docker compose ... up --build`

---

## Step 5 — Implement REL Support Bundle
Add a user-facing support bundle generator.

Required interface (choose one primary):
- Implement `scripts/winebotctl diag bundle ...`
  - OR add `scripts/diag-bundle.sh` and wire it into `winebotctl`

### Inputs
- session ID or session directory
- default to current `WINEBOT_SESSION_DIR` if set

### Output
- A single archive (`.zip` or `.tar.gz`) written to a host-accessible path

### Deterministic structure inside archive
```
support-bundle/
  manifest.json
  app/
    version.json
    config.redacted.json
    logs/
    crash/
    traces/
  session/
    (selected session files; bounded)
  system/
    os.json
    env.redacted.json
  notes.txt
```

### Safety requirements (mandatory)
- Local-only generation by default (no upload)
- Size cap (default 200MB; configurable)
- Redaction prior to writing archive:
  - tokens/passwords/API keys
  - Authorization headers/cookies
  - VNC passwords if stored anywhere
  - env vars matching secret patterns (e.g., `*_TOKEN`, `*_PASSWORD`, `*_KEY`)
- Include only bounded logs/traces (respect rotation)
- Idempotent behavior (overwrite safely or generate timestamped bundle)

### Manifest requirements (mandatory)
`manifest.json` must include:
- bundle schema version
- WineBot version / image digest or build revision if available
- build intent (must say `rel` in release image)
- timestamp, platform (os/arch)
- included file list with size + hash
- redaction version

Add tests that verify:
- manifest exists
- size cap works
- redaction removes known secrets

---

## Step 6 — Forbidden-Feature Checks for REL
Add a CI-enforced REL validation step.

Deliverables:
- `policy/rel_forbidden_patterns.txt` containing denylist patterns such as:
  - `tests/`, `pytest`, `coverage`, `__pycache__` (tune to repo)
  - any internal “test hook” markers you define
- `scripts/ci/check-rel-forbidden.sh` that:
  1) builds REL image (`BUILD_INTENT=rel`)
  2) inspects image filesystem and config
  3) fails if forbidden patterns are found

Also enforce API route constraints:
- If routes are registries or discoverable, ensure no test-only routes exist in REL.
- Add a unit test or route registry test if applicable.

---

## Step 7 — Logging/Tracing Defaults by Intent
Implement defaults and caps keyed by intent.

Required defaults:
- DEV: verbose allowed (DEBUG/TRACE)
- TEST: INFO with deterministic artifact output
- REL: WARN by default; Support Mode can elevate to INFO (bounded)

Add REL “Support Mode”:
- user-initiated (env var or CLI toggle)
- expires automatically or clearly reversible
- does NOT enable prohibited deep diagnostics or test hooks
- enables bounded tracing/log detail sufficient for triage

---

## Step 8 — CI/CD Wiring
Update `.github/workflows`:

### PR/CI
- Build TEST image (`BUILD_INTENT=test`)
- Run smoke tests under `tests/`
- Collect and upload artifacts to a known path (recommend `artifacts/`)

### Release workflow
- Build REL image (`BUILD_INTENT=rel`)
- Run forbidden-feature check
- Publish rel tag(s) only from protected refs/tags (preserve existing policy)
- Keep existing security scans (e.g., Trivy) and provenance/SBOM steps

---

## Step 9 — Documentation
Update `README.md` and/or add docs to explain:

- what `BUILD_INTENT` means in WineBot
- how to build/run DEV/TEST/REL
- how compose profiles interact with intents (headless vs interactive)
- how to enable Support Mode safely
- how to generate a Support Bundle and what it contains

---

## Step 10 — Tests
Add/extend tests (must pass in CI):

1. **Intent gating tests**
   - verify intended defaults and gating behavior per intent
2. **Support bundle tests**
   - redaction removes known secret patterns
   - size cap enforced
   - manifest schema version present
3. **REL forbidden-feature tests**
   - REL image does not contain denylisted files/tools/routes

Prefer using existing test framework under `tests/`.

---

## Deliverables Checklist
- [ ] `docs/build-intents.md` (WineBot-specific)
- [ ] Docker build support for `BUILD_INTENT` and intent tags
- [ ] Compose wiring for build arg forwarding
- [ ] Support bundle generator (via `winebotctl` or new script)
- [ ] Redaction + size caps in bundler
- [ ] `policy/rel_forbidden_patterns.txt`
- [ ] `scripts/ci/check-rel-forbidden.sh`
- [ ] CI workflow updates (TEST in PR/CI, REL in release)
- [ ] Tests validating intent gating + support bundle + forbidden checks

---

## Acceptance Criteria (Definition of Done)
1. `BUILD_INTENT` can be set to `dev|test|rel` and produces different images per policy.
2. REL image contains no test harnesses or dev-only tooling per denylist checks.
3. REL supports generating a single Support Bundle archive for a session with redaction and a size cap.
4. CI builds TEST by default, runs tests, and uploads artifacts; release builds REL and enforces forbidden checks.
5. Documentation clearly explains how to run headless/interactive under each intent without confusing profile vs intent.

---

## PR Output
Open a PR that includes:
- clear summary of changes and rationale
- updated docs
- updated workflows
- tests passing
- brief “How to use” section in PR description:
  - how to build/run each intent
  - how to create a support bundle
