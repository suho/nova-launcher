# Nova Launcher

A macOS-first productivity launcher inspired by Raycast. The first version
focuses on local app launching through a keyboard-first command palette.

## Features

- Option-Space global launcher hotkey
- Fast local app index for `/Applications`, `/System/Applications`, and user apps
- Fuzzy app search with arrow-key navigation and Return-to-open
- Menu bar utility with reindex, settings, and quit actions
- Native Settings window for launch-at-login, theme, and shortcut customization
- Dark, light, and system appearance modes
- Local-only indexing; no network service or remote search

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM target, stages `dist/NovaLauncher.app`, and opens
the app bundle as a foreground macOS application.

## Install with Homebrew

This private repo includes a Homebrew cask that builds the app locally from the
`main` branch and installs `NovaLauncher.app`.

Prerequisites:

- Homebrew
- SSH access to `git@github.com:suho/nova-launcher.git`
- Xcode Command Line Tools with Swift 6.2 or newer

Tap the private repo with its explicit Git URL, then install the cask:

```bash
brew tap suho/nova-launcher git@github.com:suho/nova-launcher.git
brew install --cask suho/nova-launcher/nova-launcher
```

Because the cask tracks the latest `main` branch, use `--greedy` when upgrading:

```bash
brew upgrade --cask --greedy suho/nova-launcher/nova-launcher
```

To uninstall:

```bash
brew uninstall --cask suho/nova-launcher/nova-launcher
```
