# Nova Launcher Agent Guide

## Project Context

Nova Launcher is a macOS-first SwiftUI productivity launcher inspired by
Raycast. The initial scope is a keyboard-first command palette for indexing,
searching, and launching local applications.

## Repository Layout

### Package and Build

- `Package.swift`: SwiftPM package definition for the `NovaLauncher` executable.
- `script/build_and_run.sh`: canonical local build, bundle, run, debug, log, and
  verify entry point.
- `dist/`: generated app bundle output; do not hand-edit generated contents.

### Application Sources

- `Sources/NovaLauncher/App`: app entry point, delegate, and service wiring.
- `Sources/NovaLauncher/Models`: lightweight domain types.
- `Sources/NovaLauncher/Services`: app indexing, launching, hot key handling,
  icon caching, login item support, and command panel control.
- `Sources/NovaLauncher/Stores`: observable state for the launcher UI.
- `Sources/NovaLauncher/Support`: platform and utility helpers.
- `Sources/NovaLauncher/Views`: SwiftUI views for the command palette, menu bar,
  settings, app rows, icons, and shortcut recording.

## Commands

- Build and run: `./script/build_and_run.sh`
- Build and verify launch: `./script/build_and_run.sh --verify`
- Debug executable: `./script/build_and_run.sh --debug`
- Stream app logs: `./script/build_and_run.sh --logs`
- Stream telemetry logs: `./script/build_and_run.sh --telemetry`
- SwiftPM build only: `swift build`

## Engineering Guidance

- Prefer native macOS SwiftUI and AppKit interop patterns over iOS-style
  assumptions.
- Keep app behavior local-first; do not add network services or remote search
  without explicit product direction.
- Keep keyboard workflows fast and predictable. Search, selection, and launch
  paths should avoid unnecessary async hops or visible layout shifts.
- Use existing services and store boundaries before adding new global state.
- Treat `ApplicationEntry`, indexing, fuzzy matching, icon caching, and launcher
  state as shared behavior; broaden verification when changing them.
- Keep generated bundle metadata in `script/build_and_run.sh` unless the project
  gains a dedicated app target or packaging system.

## Verification Expectations

- App changes require `./script/build_and_run.sh --verify`.
- Shared behavior changes, including `ApplicationEntry`, indexing, fuzzy
  matching, icon caching, and launcher state, should get broader verification.

## Git Workflow

- Check `git status --short --branch` before editing and before committing.
- Keep commits focused on the requested change.
- Commit and push after each code or documentation change.
- Do not revert user changes unless the user explicitly asks for that.
