## ADDED Requirements

### Requirement: Queue row actions are accessible without pointer hover
The app SHALL expose play and remove actions for applicable queue rows without requiring pointer hover. Removable rows SHALL keep a stable remove control, and assistive technologies SHALL receive named actions for playing and removing a row.

#### Scenario: VoiceOver plays a queued track
- **WHEN** a VoiceOver user focuses a queued track and invokes its Play action
- **THEN** the app starts that queued track using the same queue semantics as a mouse double-click

#### Scenario: Keyboard or VoiceOver removes a manual queue item
- **WHEN** a removable manual queue row is not pointer-hovered and the user invokes its remove control or named Remove action
- **THEN** the item is removed from the manual queue
