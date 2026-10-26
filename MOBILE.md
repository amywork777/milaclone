# Pinboard on iPhone

The native SwiftUI companion lives in `mobile/Pinboard.xcodeproj`. It keeps a local notebook, works offline, and syncs directly with the paired Mac. No cloud account or hosted storage is used. The desktop Rivet designs remain alternatives awaiting selection.

## Start on your Mac

1. Open `Start Pinboard.command` for the desktop notebook. After updating this code, restart it so the sync protections are loaded.
2. Open `Start Pinboard Sync.command`. Leave its terminal running while using sync.
3. Open http://127.0.0.1:5199 on your Mac. Copy the connection card. This contains a private credential; do not share it.
4. On your iPhone, open Pinboard's **Sync settings** screen and paste that card. Allow local network access. Both devices need to be on the same reachable local network.

The desktop app remains on localhost port 5189. The separate authenticated HTTPS service listens on port 5198. Setup is only available on localhost port 5199. If macOS asks about incoming connections, allow Pinboard's Node process on your private network. Guest Wi-Fi often blocks device-to-device connections.

The phone pins the exact Mac certificate and stores pairing credentials in Keychain. If the Mac's IP changes, copy a fresh card and reconnect. Stop sync and run `npm run sync:revoke`, then restart sync, to invalidate the old credential and pair again. This disconnects all paired phones.

## Install the iPhone app

The development build was signed and installed on Amy’s paired iPhone 15 Pro on 2026-10-25. For later builds, open `mobile/Pinboard.xcodeproj` in Xcode, choose your Apple development team in Signing & Capabilities, select your iPhone, and Run. The app uses bundle identifier `com.amy.pinboard.mobile`. A personal signing team may require periodic reinstallation. See `mobile/README.md` for exact local build and test commands and the environment limitations.

## How changes are protected

- Phone edits save to the local notebook before a network request. Failed requests leave them pending. The phone disables editing during a sync acknowledgment.
- Notes, tasks, nested boards, groups, images, and files use the existing Mac schema. Layout coordinates and unknown card/task metadata survive phone edits.
- Sync transfers a complete notebook snapshot, including referenced attachment bytes. Limits are 25 MiB per file and 100 MiB total attachments. This first version is intended for a personal notebook, not a large photo archive.
- If both devices changed, the phone keeps its copy and offers **Keep both**. The Mac retains its current notebook and adds the phone copy inside a new board. Repeating a request after a lost response does not duplicate that board.
- Before each accepted phone write, the Mac saves a complete snapshot in `data/sync/backups/`. These private files include attachments. They are not committed to Git.
- After phone sync, reload the Mac browser to see it. Old browser tabs cannot overwrite the new notebook or undo across a phone sync. Copy any unsaved text before reloading. Failed Quick Notes saves stay pending until acknowledged.
- Sync runs on foreground/reconnection and is also available manually. It does not promise background syncing or remote access away from the Mac's network.

## Validation

Node tests exercise authentication over HTTPS, compare-and-swap writes, concurrent changes, lost acknowledgments, Keep both, attachment bytes, malformed paths/graphs, pairing-page origin checks, and stale-browser protections. All tests use temporary data directories. Native model and URLSession transport checks are under `mobile/Tests/`.

The signed device build and physical iPhone installation succeeded. Pairing and end-to-end phone/Mac interaction still need to be verified. No usable iOS Simulator runtime was installed during implementation; no runtime download was attempted.

The automatic first launch was blocked because the iPhone was locked. Unlock the phone and open Pinboard to complete pairing.
