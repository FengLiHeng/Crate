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
The app SHALL download and install an update only after the user explicitly confirms the action.

#### Scenario: User confirms installation
- **WHEN** the user confirms installation of a compatible newer release
- **THEN** the app downloads the zip, extracts a Crate app bundle, validates its bundle identifier and version, schedules replacement of the current app, and quits for relaunch

#### Scenario: Download or validation fails
- **WHEN** the download, extraction, bundle validation, or write-permission check fails
- **THEN** the app preserves the current installation and shows a Chinese failure message

#### Scenario: User cancels installation
- **WHEN** the update dialog is dismissed without confirmation
- **THEN** the app does not download or replace the current app
