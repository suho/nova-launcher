# Nova Launcher

A macOS-first productivity launcher inspired by Raycast. The first version
focuses on local app launching through a keyboard-first command palette.

## Screenshots

![Nova Launcher command palette search](docs/screenshots/command-palette-search.png)

![Nova Launcher settings items shortcuts](docs/screenshots/settings-items-shortcuts.png)

## Features

- Option-Space global launcher hotkey
- Fast local app index for `/Applications`, `/System/Applications`, and user apps
- Fuzzy app and command search with arrow-key navigation and Return-to-open
- Basic focused-window commands for left half, right half, maximize, and next desktop
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

This public repo includes a Homebrew cask that builds the app locally from the
latest `main` branch and installs `NovaLauncher.app`.

Prerequisites:

- macOS Tahoe 26.0 or newer
- Homebrew
- Xcode Command Line Tools with Swift 6.2 or newer

Tap the repo with its explicit public Git URL, then install the cask:

```bash
brew tap suho/nova-launcher https://github.com/suho/nova-launcher.git
brew install --cask suho/nova-launcher/nova-launcher
```

The explicit URL is required because this repository is named `nova-launcher`
rather than `homebrew-nova-launcher`.

If you previously tapped the private SSH URL, retap with the public URL first:

```bash
brew untap suho/nova-launcher
brew tap suho/nova-launcher https://github.com/suho/nova-launcher.git
```

Because the cask uses `version :latest`, use `--greedy` when upgrading:

```bash
brew upgrade --cask --greedy suho/nova-launcher/nova-launcher
```

To uninstall:

```bash
brew uninstall --cask suho/nova-launcher/nova-launcher
brew untap suho/nova-launcher
```
