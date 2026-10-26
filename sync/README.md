# Direct Mac sync

Run `npm run sync` with Node 24. The existing desktop server should run the same revision of the app so its epoch guards protect writes from stale tabs. Setup: http://127.0.0.1:5199. Protocol: `../mobile/SYNC-CONTRACT.md`.

Configuration: `DATA_DIR`, `UPLOAD_DIR`, `ASSET_DIR`, `SYNC_PORT` (5198), `SETUP_PORT` (5199). Use the same data/upload directories as the desktop process. Credentials and pre-write backups live in `DATA_DIR/sync/` and must stay private. TLS certificates and bearer credentials are generated locally; they are never logged. Stop the sync server before `npm run sync:revoke`, then restart it.

SQLite BEGIN IMMEDIATE serializes desktop content mutation and phone compare-and-swap. A sync epoch invalidates desktop undo history and page credentials. Keep content routes nested within `workspace-routes.js`: Express defers unwinding a completed router, so separate sibling routers would release the epoch transaction too early.

Snapshots are canonicalized for stable revisions. Durable operation receipts make lost-response retries idempotent, including after later Mac edits. Keep both remaps IDs and imports the full phone tree under one board. Files use unique safe names and cannot overwrite differing existing bytes. Backups precede database mutation; a failed save is not acknowledged. File writes may leave unreferenced files after a failure, but never replace existing attachment contents. Old uploaded files are retained for desktop undo. Monitor local disk space and archive old sync backups when needed.

Tests: `npm test`. Test directories are isolated from the live notebook and uploads.
