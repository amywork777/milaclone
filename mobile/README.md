# Pinboard for iPhone

Native SwiftUI companion, iOS 17+. Local notebook storage works before pairing. Notes, links, task lists, images, files, nested boards and columns share the Mac schema. The iPhone reads spatial content as vertical groups while retaining Mac coordinates. This does not apply any desktop Rivet direction.

## Build and install

Open `Pinboard.xcodeproj` in Xcode, select your personal development team and an available iPhone. Use a unique bundle identifier if your signing account requires it. Normal scheme builds may request additional iOS platform components; the target-only command below builds with the installed SDK. No simulator runtime or platform component was downloaded for this implementation.

The project is generated from `project.yml` with XcodeGen:

```sh
xcodegen generate --spec mobile/project.yml
```

From the repository root, this unsigned arm64 target build passed with the installed iPhoneOS 26.2 SDK:

```sh
xcodebuild -project mobile/Pinboard.xcodeproj -target Pinboard \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO \
  SYMROOT="$PWD/mobile/DerivedData/Build/Products" \
  OBJROOT="$PWD/mobile/DerivedData/Build/Intermediates.noindex" build
```

The usual `-scheme Pinboard -destination 'generic/platform=iOS'` invocation was blocked by Xcode reporting its iOS 26.2 platform component was not installed, despite the SDK being present. The target build compiles and links against that SDK without destination selection. The optional color catalog is excluded from the build because this installation's asset compiler also requires an unavailable simulator runtime. `PinboardTheme` supplies the matching adaptive tint directly. A custom home-screen icon is not included yet. The parent build subsequently signed the app using the existing development identity and installed it on Amy’s paired iPhone 15 Pro. Device pairing and end-to-end interaction remain to be verified.

## Connect

1. Run the Mac's protected sync service using the repository's sync setup instructions. Its local setup page is normally `http://127.0.0.1:5199` on the Mac.
2. On iPhone, open the board options menu, then **Sync settings**.
3. Paste the Mac's private pairing JSON under **Connect your Mac**, then connect. Allow local-network access when iOS asks. Both devices must be on the same local network; the Mac must remain running.
4. An empty phone downloads the Mac notebook. Existing phone notes require **Keep both**, which saves the phone copy as a new board alongside the Mac notebook. They are never silently replaced.

Pairing accepts HTTPS local-network addresses and `.local` names only, plus loopback for local testing. Credentials live in a device-only Keychain item. Every request checks the SHA-256 fingerprint of the exact DER leaf certificate. No redirects are followed. There is no cloud service.

Edits save immediately in Application Support/Pinboard/notebook.json. Workspace, acknowledged revision, dirty flag, and conflict revision are one atomic file. iOS file protection covers that file. Failed saves leave the previous in-memory and on-disk snapshot in place and display an error; corrupt saved data is preserved and editing blocked. Keep a device backup before manually recovering corrupted storage.

Sync runs manually, on foreground, and when network connectivity returns. Unsynced changes remain dirty on request failure. Editing is disabled while exchanging snapshots. A conflict preserves local edits and offers Keep both. A lost successful response retries the same snapshot and revision; the Mac's protocol is idempotent. There is no background-sync guarantee.

## Checks

These require the installed command-line Swift SDK and Python 3, not a simulator:

```sh
mkdir -p mobile/.build
xcrun swiftc mobile/Pinboard/Notebook.swift mobile/Tests/ModelChecks.swift \
  -o mobile/.build/model-checks
mobile/.build/model-checks mobile/.build/swift-workspace.json
python3 mobile/Tests/transport-checks.py
```

The model suite checks JSON round trips, unknown fields, layout, task metadata, explicit nulls, integer millisecond timestamps, offline attachments, revision/dirty/conflict restart persistence, atomic acknowledgements, corrupt-file preservation, failed writes, nested-board deletion, rejection of nested columns, and attachment pruning. It emits an optional real Swift workspace fixture for validation against the Mac implementation.

The transport suite uses an ephemeral loopback HTTPS fixture with a self-signed certificate. It checks pinned GET/POST, typed 409 conflicts, rejected redirects and wrong pins, insecure/public-host pairing rejection, and that the server receives neither redirected requests nor a wrong-pin credential. It uses test-only credentials and never reads the real notebook.

## Verification still needed

No usable simulator runtime was installed, so no screenshot or interaction testing is claimed. Verify on the signed iPhone: light/dark appearance, large Dynamic Type, VoiceOver, sheet/keyboard behavior, photo and file pickers, local-network permission, phone-to-Mac and Mac-to-phone edits, offline restart, concurrent edits and Keep both, dropped acknowledgements, token revocation, and certificate changes.

The snapshot format rewrites the notebook (including base64 attachments) on each edit. Correctness is tested, but performance near the 100 MiB attachment limit is not measured on hardware. Thumbnail decoding is bounded and cached. Attachment bytes remain original; images are not fetched from external URLs. There is no spatial rearrangement or drag-and-drop on iPhone in this foundation.

The automatic first launch was blocked because the iPhone was locked. Unlock the phone and open Pinboard to complete pairing.
