## Update 1.0.6
#### Changes
- Card layout in the list is now responsive
- Card, slot selector and graph stats are now translatable
- Global stat slots settings are now aligned with per-app slot UI-wise
- Upated translations
#### Fixes
- Fixed Ukrainian translation
- Fixed UI in the statuspages being inconsistent

## Update 1.0.4 (Play Store's 1.0.5)
#### Changes
- Updated notification channels names and descriptions.
- Updated notification channels, separate channels for:
    - Incident raised
    - Incident resolved
    - Server goes offline
    - Server comes back online
- Notification texts, channel names and descriptions are now translatable.
#### Fixes
- Fixed a bug with "server is offline" notification was sent when user is offline (server may not be offline, actually lol)

## Update 1.0.3
#### Changes
- Updated Ukrainian translations.
#### Fixes
- Fixed a bug where server pages only updated when viewed as a list and failed to refresh when opened individually.

## Update 1.0.2
#### Changes
- **UI Overhaul**:
  - Components are now displayed horizontally.
  - Limited to 1 maintenance or incident per block for better readability.
  - Shortened preview length for maintenance/incident titles and bodies.
  - Updated "no maintenance/no incident" state UI.
  - Overall improvements to paddings and visual consistency.
- **Markdown Support**: Status updates are now parsed as Markdown, supporting links and formatting.
- **Intro Experience**: Updated the onboarding flow to allow selection of multiple demo servers and Statuspages.
- **Editor Improvements**:
  - Added recommended servers and statuspages to editors for quicker setup.
#### Fixes
- Fixed a bug in the server edit page where the save button wouldn't appear when adding a new server.
- Fixed paddings on incident labels.
- Fixed missing English translation strings.
#### Known Issues
- Ukrainian translation is still incomplete in some areas.

## Update 1.0.1
#### Changes
- **Translation Engine**: Initial implementation of the localization system.
- **Optimizations**: Significant UI performance optimizations and general code cleanup.
#### Fixes
- Fixed various bugs throughout the application.

## Update 1.0.0 `REBIRTH`
#### Changes
- **Project Rebirth**: Complete overhaul of the original prototype.
- **New Features**:
  - Added TCP Pinging for basic connectivity monitoring.
  - Added Atlassian Statuspage monitoring support.
  - Implemented Background Monitoring with foreground service notifications.
#### Known Issues
- Statuspage UI may be buggy or inconsistent in some views.

## Update 0.0.1 `PROTOTYPE` (2023)
#### Changes
- **Initial Prototype**: Basic release focused on AIO.php monitoring.
- **Limitations**: Only the URL was changeable; no other configuration options were available.
- **UI**: Early-stage UI with Material Design 2 aesthetics.

---
> Template for later updates
```Markdown
## Update 1.0.0
#### Changes
#### Fixes
#### Known Issues
#### Miscellaneous
```
