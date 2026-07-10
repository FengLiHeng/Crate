# app-update Specification

## Purpose
Define how Crate discovers, presents, downloads, and installs updates published through GitHub Releases.
## Requirements
### Requirement: Check latest GitHub release
The app SHALL allow the user to check for the latest published full GitHub Release for `FengLiHeng/Crate` from inside the app.

#### Scenario: Newer release is available
- **WHEN** the user checks for updates and the latest release tag is greater than the current bundle version
- **THEN** the app shows the release version, a release note summary, and an action to download and install the update

#### Scenario: Current version is up to date
- **WHEN** the user checks for updates and the latest release tag is equal to or lower than the current bundle version
- **THEN** the app tells the user that the current version is already up to date

#### Scenario: Release check fails
- **WHEN** GitHub cannot be reached or the response cannot be parsed
- **THEN** the app keeps playback and library state unchanged and shows a Chinese failure message

### Requirement: Select a compatible release asset
The app SHALL select a compatible macOS zip asset from the latest release before offering installation.

#### Scenario: Compatible arm64 zip exists
- **WHEN** a newer release includes a zip asset matching the Crate macOS arm64 naming convention
- **THEN** the app uses that asset's download URL for the update

#### Scenario: No compatible asset exists
- **WHEN** a newer release has no compatible Crate macOS zip asset
- **THEN** the app does not offer installation and tells the user that the release package is missing

### Requirement: Download and install confirmed update
The app SHALL download and install an update only after the user explicitly confirms the action, and SHALL keep the user informed while download and installation handoff are in progress.

#### Scenario: User confirms installation
- **WHEN** the user confirms installation of a compatible newer release
- **THEN** the app downloads the zip, extracts a Crate app bundle, validates its bundle identifier and version, schedules replacement of the current app, and quits for relaunch

#### Scenario: Download progress is visible
- **WHEN** the update zip is downloading
- **THEN** the app shows live progress with a percentage when the total size is known, or a growing downloaded size when the total size is unknown

#### Scenario: Installation handoff starts
- **WHEN** the update zip has downloaded and validated successfully
- **THEN** the app starts an installer process that is independent from the current app process and immediately begins quitting the current app

#### Scenario: Download or validation fails
- **WHEN** the download, extraction, bundle validation, or write-permission check fails
- **THEN** the app preserves the current installation and shows a Chinese failure message

#### Scenario: Installer handoff fails
- **WHEN** the app cannot start the installer process
- **THEN** the app does not quit and shows a Chinese failure message

#### Scenario: User cancels installation
- **WHEN** the update dialog is dismissed without confirmation
- **THEN** the app does not download or replace the current app

### Requirement: Validate GitHub release asset integrity
The app SHALL only offer installation for an asset whose name exactly matches `Crate-<tag>-macOS-<architecture>.zip`, whose download URL belongs to the expected `FengLiHeng/Crate` HTTPS GitHub Release path, and whose GitHub metadata contains a positive file size and a valid SHA-256 digest. After download, the app MUST verify both the actual file size and SHA-256 digest before extraction or replacement.

#### Scenario: Downloaded asset passes integrity validation
- **WHEN** the exact compatible GitHub Release asset downloads with the expected byte size and SHA-256 digest
- **THEN** the app proceeds to extract and validate the Crate app bundle

#### Scenario: Asset integrity metadata is missing
- **WHEN** the compatible asset has no positive size or valid SHA-256 digest in the GitHub API response
- **THEN** the app does not offer installation and shows a Chinese integrity-metadata failure message

#### Scenario: Downloaded asset integrity does not match
- **WHEN** the downloaded file size or SHA-256 digest differs from the GitHub Release asset metadata
- **THEN** the app deletes the temporary update work directory, preserves the current installation, and shows a Chinese integrity failure message

#### Scenario: Asset URL or name is not exact
- **WHEN** a zip uses a similar name or a download URL outside the expected HTTPS GitHub Release path
- **THEN** the app rejects that asset and does not offer installation
