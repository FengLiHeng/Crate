## ADDED Requirements

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
