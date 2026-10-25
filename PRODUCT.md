# Pinboard

<!-- impeccable:product-schema 1 -->

## Platform
Current: local web app on Mac. Target: Mac and iPhone, sharing the same notebook. Amy confirmed iPhone and cross-device synchronization; the sync transport is awaiting her preference.

## Users and purpose
Amy wants a personal visual notebook very similar to Milanote. FigJam feels too disorganized. She confirmed a mix of notes, images, links, and tasks, and explicitly prefers forking an existing project.

## Foundation
Fork of ellshep/milaclone, MIT licensed. Preserve its native canvas, drag/resize behavior, nested boards, columns, and quick task notes. Add organization and recovery around that canvas. The existing Node/SQLite service stores content on disk.

## Constraints
Personal use. Amy explicitly chose files saved locally on her Mac. Keep user data and uploaded files out of Git. Do not confuse a public source-code fork with public notebook data. A future mobile app must not silently move the notebook to a public service.

## Simplicity and mobile
Amy asked for the experience to be “infinitely simple” and requested Rivet alternatives. She clarified the desired balance as “like Notion simple but less corporate and like FigJam too”: clear reading and writing, spatial freedom, and a warm personal feel. The existing permanent sidebar and tool rail are implementation choices, not product requirements. The initial isolated directions are Just the canvas, A single page, and Board tabs. Page with room and Ideas in groups explore the latest clarification; no direction has been selected or applied.

Mobile is part of the intended product, not just a smaller desktop preview. Preserve notes, images, links, and tasks, with obvious adding, reading, editing, and board navigation by touch. The current API depends on a Mac-hosted Express/SQLite server and is not yet an independently usable mobile app. Preserve a local offline copy on each device. Choose iCloud or direct Mac sync before implementing the transport. Do not describe responsive web views or a remote-server wrapper as a completed offline iPhone app.
