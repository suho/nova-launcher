# Nova Launcher Agent Guide

## Required Workflow

- After each code or documentation change, commit and push the change.
- After each app change, run `./script/build_and_run.sh --verify` to check that the app builds and launches.
- Do not revert user changes unless the user explicitly asks for that.

## Project Overview

Nova Launcher is a macOS-first SwiftUI productivity launcher inspired by
Raycast. The initial scope is a keyboard-first command palette for indexing,
searching, and launching local applications.

## Repository Map

- `Package.swift`: SwiftPM package definition for the `NovaLauncher` executable.
- `Sources/NovaLauncher/App`: app entry point, delegate, and service wiring.
- `Sources/NovaLauncher/Services`: app indexing, launching, hot key handling,
  icon caching, login item support, and command panel control.
- `Sources/NovaLauncher/Stores`: observable state for the launcher UI.
- `Sources/NovaLauncher/Views`: SwiftUI views for the command palette, menu bar,
  settings, app rows, icons, and shortcut recording.
- `Sources/NovaLauncher/Models`: lightweight domain types.
- `Sources/NovaLauncher/Support`: platform and utility helpers.
- `script/build_and_run.sh`: canonical local build, bundle, run, debug, log, and
  verify entry point.
- `dist/`: generated app bundle output; do not hand-edit generated contents.

## Common Commands

- Build and run: `./script/build_and_run.sh`
- Build and verify launch: `./script/build_and_run.sh --verify`
- Debug executable: `./script/build_and_run.sh --debug`
- Stream app logs: `./script/build_and_run.sh --logs`
- Stream telemetry logs: `./script/build_and_run.sh --telemetry`
- SwiftPM build only: `swift build`

## Implementation Notes

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

## Git Expectations

- Check `git status --short --branch` before editing and before committing.
- Keep commits focused on the requested change.
- Push the branch after each required commit.
