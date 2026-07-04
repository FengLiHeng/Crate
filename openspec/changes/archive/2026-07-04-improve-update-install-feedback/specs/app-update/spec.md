## MODIFIED Requirements

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
