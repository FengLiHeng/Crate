## ADDED Requirements

### Requirement: Preserve a valid state when backward skipping reaches the boundary
When the user requests the previous track and every earlier candidate is unavailable, the app SHALL NOT leave the current playback state pointing at an unavailable candidate with no playback engine. If the originating track remains playable, the app SHALL restore it at the beginning; if no candidate including the origin is playable, the app SHALL stop safely and report that no playable track exists.

#### Scenario: All earlier tracks are unavailable
- **WHEN** the current context track is playable and every earlier track fails availability or engine construction while processing Previous
- **THEN** the app restores the originating track at 0 seconds and keeps a valid playback state

#### Scenario: Origin also becomes unavailable
- **WHEN** all earlier tracks and the originating track fail while processing Previous
- **THEN** the app stops playback without looping or remaining on an unavailable track and reports that no playable track exists
