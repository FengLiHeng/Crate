## 1. Download Progress

- [x] 1.1 Add a progress value type that formats percent and byte counts.
- [x] 1.2 Replace one-shot zip download with streaming download and progress callbacks.
- [x] 1.3 Update `AppState` and the update dialog to render determinate or indeterminate download progress.

## 2. Installation Handoff

- [x] 2.1 Start the installer script as a detached process with output redirected to a temporary log.
- [x] 2.2 Report installer launch failures without quitting the app.
- [x] 2.3 Keep backup-restore behavior for partial replacement failures.

## 3. Verification

- [x] 3.1 Add tests for progress formatting and installer launch arguments.
- [x] 3.2 Run OpenSpec validation, Swift tests/build, and bundle generation.
- [x] 3.3 Mark tasks complete and archive the change.
