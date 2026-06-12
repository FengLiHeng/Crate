## Why

The app currently starts with bundled sample music, which makes the library state feel artificial and can hide real empty-library behavior. Import should also support the expected desktop workflow of choosing either specific music files or a folder whose supported audio files are added in bulk.

## What Changes

- Remove bundled virtual/sample music data from the default user-facing library.
- Change the top-right `+` action into a secondary menu with separate choices for importing files or importing a folder.
- Preserve multi-file import for explicit file selection.
- Add folder import behavior that scans the selected directory for supported music files, such as `.mp3`, and adds matching files to the song list.
- Keep unsupported files filtered out and retain existing import feedback such as toast counts and duplicate handling.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `music-library`: Initial library behavior changes from seeded sample songs/playlists to an empty real library state until the user imports music.
- `library-import`: The `+` import entry point changes to a menu that supports both file selection and folder selection, with folder selection importing supported audio files from the selected directory.

## Impact

- Affected UI: top-right library/import control, import menu, empty library state, and song table state.
- Affected logic: sample data seeding, app/library initialization, file import flow, folder scanning/filtering, duplicate detection, metadata parsing, and persistence.
- Affected specs: `openspec/specs/music-library/spec.md` and `openspec/specs/library-import/spec.md`.
