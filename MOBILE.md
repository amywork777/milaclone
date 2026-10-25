# iPhone companion

## Confirmed scope

- iPhone, alongside the existing Mac notebook.
- The same boards, notes, images, links, and tasks on both devices.
- Local files on the Mac; local offline availability on the iPhone.
- An extremely simple interface with native touch navigation and one obvious adding action.
- The three desktop Rivet directions remain alternatives, awaiting selection.

## Sync choice pending

iCloud sync can maintain local copies while exchanging changes through Amy’s iCloud account. Direct Mac sync avoids a cloud transport but requires the Mac to be running and reachable. Do not select a transport or upload notebook content until Amy answers.

The existing Express/SQLite API is Mac-only. A mobile shell alone would still depend on that server, so mobile work needs durable device storage, pending changes, attachment transfer, deletion tracking, and conflict recovery. Preserve current SQLite IDs and the backup format during any migration. Never place the live SQLite database in a shared cloud folder and assume this handles concurrent edits.

## Implementation sequence

1. Confirm transport and retain the selected desktop design separately from mobile infrastructure.
2. Add a local iPhone store and an adapter for the existing notebook schema.
3. Add durable sync state and attachment transfer. Keep unsent changes until acknowledgment; recover conflicts without silently discarding notes.
4. Build the iPhone interface around a board list, readable cards, and a focused add/edit sheet. Use native navigation, system text styles, and 44-point touch targets.
5. Verify note/task/image edits across devices, offline edits followed by reconnect, deletion conflicts, restart persistence, and backup recovery.
6. Sign and install on the iPhone after local build checks pass.

## Current environment check — 2026-10-25

Xcode 26.2 is installed. No usable iOS Simulator runtime is installed. The filesystem reported only 117 MiB available, and xcodebuild reported a cache-write failure because the disk was full. Do not download runtimes or claim a verified iPhone build until space is available. No mobile app or sync implementation has shipped yet.

## Platform references

- [Apple: choosing a CloudKit approach](https://developer.apple.com/documentation/cloudkit/deciding-whether-cloudkit-is-right-for-your-app)
- [Apple’s sync-engine sample and signing requirements](https://github.com/apple/sample-cloudkit-sync-engine)
