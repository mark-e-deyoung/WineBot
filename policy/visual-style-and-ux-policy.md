# WineBot Visual Style & User Experience Policy

This document defines the visual standards and functional UX principles for the WineBot Dashboard and related UI components.

## 1. Aesthetic: "Cyber-Industrial Dark"
The interface should feel like a high-performance terminal or industrial control center. 
- **Principles:** High contrast, deep backgrounds, vibrant status accents, and geometric shapes.
- **Tone:** Professional, reliable, and technically transparent.

## 2. User Experience (UX) Principles

### Responsive Design
The system must be usable across all form factors.
- **Mobile (360px+):** Controls must transition to a drawer/bottom-sheet. VNC viewport must remain prioritized.
- **Desktop:** Sidebar layout with fixed VNC viewport.

### Accessibility (A11y)
Target WCAG 2.1 AA compliance where feasible.
- **Keyboard Nav:** Every button and input must be reachable via `Tab` and activatable via `Enter`/`Space`.
- **ARIA:** Icon-only buttons must have `aria-label` or `title` attributes.
- **Contrast:** Text contrast ratios must meet a minimum of 4.5:1.

### Feedback & Consistency
- **No Silent Failures:** Actions must trigger Toast notifications or visible state changes.
- **Confirmations:** Destructive actions (Shutdown, Deleting artifacts) must require a secondary confirmation step.
- **Idempotency:** UI should handle repeated clicks gracefully (e.g., disabling a button while an action is in flight).

## 3. Core Palette (CSS Variables)
Components **MUST** use these variables. Hardcoded hex values are prohibited.

| Variable | Hex | Usage |
| :--- | :--- | :--- |
| `--bg` | `#0b1114` | Main page background |
| `--accent` | `#4dd0a1` | Mint Green - OK / Primary |
| `--accent-2` | `#5ec4ff` | Electric Blue - Info / Links |
| `--danger` | `#ff6b6b` | Crimson - Errors / Destructive |

## 4. Enforcement Mechanisms
- **Tier 1 (Audit):** Manual review of mobile responsiveness and basic keyboard accessibility.
- **Tier 2 (Automated Scan):** Future integration of Google Lighthouse for A11y/Performance scores.
- **Tier 3 (Visual Regression):** Pixel-comparison testing in CI to prevent layout drift.
