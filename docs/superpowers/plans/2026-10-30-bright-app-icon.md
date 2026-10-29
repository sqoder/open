# Bright App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Suqi's detailed, pale character icon with a bright, recognizable geometric magpie.

**Architecture:** Generate one square master, crop any outer padding, and derive all existing PNG slots and the standalone ICNS. Keep Xcode's existing `ASSETCATALOG_COMPILER_APPICON_NAME` wiring unchanged.

**Tech Stack:** Magpie `generate_image`, macOS `sips`/`iconutil`, existing Xcode build.

**Spec:** User request in this conversation: bright, eye-catching, simple rather than dark or technically elaborate; use the installed magpie-image generator; implement and show the result.

## Global Constraints

- Preserve the pre-existing `scripts/install.sh` modification.
- Do not change terminal behavior or release version.
- Replace only icon resources plus this plan and a high-resolution preview.

## Review Focus

- Verify all ten asset slots have the exact required pixel dimensions.
- Inspect the small icon for recognizable silhouette and adequate contrast.
- Confirm the Release app bundle contains the rebuilt asset catalog.

### Task 1: Generate and Install Icon

**Files:**
- Create: `screenshots/suqi-icon.png`
- Modify: `suqi/Resources/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `suqi/Resources/AppIcon.icns`

- [ ] Generate a square master with a simple geometric magpie, vivid cyan-to-blue background, white/navy bird, warm accent, no text or mockup.
- [ ] Crop excess outer padding and inspect the master.
- [ ] Resize the master into the existing PNG filenames: 16, 32, 32, 64, 128, 256, 256, 512, 512, 1024 pixels according to `Contents.json`.
- [ ] Rebuild `AppIcon.icns` from an iconset using the same master.

### Task 2: Verify

- [ ] Check every PNG's pixel dimensions and inspect 512px and 32px previews.
- [ ] Build the Release scheme without running the install script.
- [ ] Confirm the built app contains `AppIcon.icns` and `Assets.car`; report code-analysis findings separately without expanding the icon change.
