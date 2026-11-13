## Update 1.1.2 (Token-Budgeted StatusPage Details & Clearer Incident Schema)
#### Changes
- Reworked `ptk_get_statuspage_details` in `lib/services/mesh_service.dart` to return a compact `summary`, `status_breakdown`, non-operational `degraded_components` (capped at 25 with `truncated_degraded_components`), and compact `active_incidents`, eliminating Gemini Nano `countTokens` overflows on large pages like Cloudflare (484 components). Added optional `include_all_components` (default `false`, capped at 50) to `mesh_service.dart` and `assets/mesh_tools.json`.
- Clarified `ptk_list_incidents` and its `statuspage_id` parameter description in both `lib/services/mesh_service.dart` and `assets/mesh_tools.json` to instruct models to omit or pass `'all'` instead of guessing placeholder IDs like `'statuspage-1'`.
- Bumped `PTK` to `1.1.2+26111302`.

## Update 1.1.1 (Mesh Reliability & Cold-Start Support)
#### Changes
- Registered `PtkMeshService` tools, called `meshClient.startListening()`, and synced declared schemas early in `AppEngine.start()` immediately after loading Hive data (before awaiting network/dictionary setup).
- Added headless cold-start entrypoint `m3xMeshMain()` (`AppEngine.startHeadlessForMesh()`) and `com.puzzak.m3x.mesh.HEADLESS_ENTRYPOINT` manifest metadata so PTK answers mesh queries even when its UI is closed or backgrounded.
- Updated `ptk_list_incidents` to accept optional `statuspage_id` (aggregating across all status pages for omitted/`"all"`/`"*"`), support `offset`/`limit` pagination (capped at 10), and tag results with `statuspage_id` and `statuspage_name`.
- Added case-insensitive ID, name, and slug resolution across `ptk_get_statuspage_details`, `ptk_list_incidents`, `ptk_get_incident_details`, and `ptk_get_server_telemetry`, returning compact structured guidance listing valid IDs when not found.
- Synced `assets/mesh_tools.json` schemas with updated tool definitions.

## Update 1.1.0 (Mesh Integration)
#### Changes
- Integrated Puzzak Inter-App Agentic Mesh Protocol (`m3x_mesh`).
- Initialized `M3xMeshClient` with `localAppId: 'ptk'`.
- Implemented `PtkMeshService` exporting 7 MCP/OpenAPI tools:
  - `ptk_list_statuspages`: lists monitored status pages with indicators and active incident counts.
  - `ptk_get_statuspage_details`: component status breakdown, operational summary, and health metrics.
  - `ptk_list_incidents`: paginated incidents with truncated update descriptions.
  - `ptk_get_incident_details`: full chronological timeline and affected components.
  - `ptk_ping`: TCP/socket latency benchmarks (min/avg/max/packet loss).
  - `ptk_list_servers`: monitored servers with online state and latency.
  - `ptk_get_server_telemetry`: scalar telemetry metrics (CPU, RAM, network throughput, uptime).
- Declared Android package visibility queries and ContentProvider authority (`page.puzzak.ptk.mesh`).

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
