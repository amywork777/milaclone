# Direct sync contract v1

The native app works offline with a persisted Workspace and the last acknowledged revision. Requests require `Authorization: Bearer <token>` over HTTPS. Pairing JSON supplied by Mac localhost-only setup: `{ "version":1, "url":"https://192.168.x.x:5198", "token":"...", "certificateSHA256":"lowercase hex SHA256 of DER leaf certificate" }`. Pin the certificate exactly; do not accept arbitrary server trust or redirects. Store credentials in Keychain. iOS local network permission required. No cloud services.

GET /v1/notebook -> `{revision:string, workspace:Workspace}`.
POST /v1/notebook `{baseRevision:string, workspace:Workspace}` -> same envelope. Complete snapshot replacement only if revision matches. Retrying an identical successful write is idempotent even if the acknowledgment was lost. On concurrent edits, status409 `{error:'conflict', revision, workspace}`. Do not replace local edits on conflict.
POST /v1/recover `{baseRevision:string, workspace:Workspace}` -> same envelope. Explicit Keep both action: server retains Mac notebook and adds a new board containing the phone snapshot, remapping IDs and preserving attachments. 409 if Mac changed again; show retry without discarding local data.
GET /v1/health -> authenticated `{ok:true,protocol:1}`.

Workspace = `{rootCanvasId:string, canvases:[Canvas], items:[Item], files:{[path:string]:base64}}`.
Canvas = `{id,title,parentCanvasId:null|string,color:null|string,icon:null|string,createdAt:number milliseconds}`.
Item = `{id,canvasId,parentItemId:null|string,type,x,y,w,h:null|number,z,color:null|string,data:JSON object,createdAt:number milliseconds}`. Preserve unknown data fields and todo task fields through round trips.
Types: note (title/body), link(title/url), todo(title/tasks:[{id,text,done,...}]), image/file(src/name/mime), board(childCanvasId), column(title), comment(body). Board title lives on child Canvas; item owns childCanvasId. Column children parentItemId references column. Native app should preserve x/y/layout even if displayed in vertical groups.
Files map keys are complete local paths such as `/uploads/unique.jpg` or `/assets/coast.jpg`. Only referenced attachments included. New phone files use `/uploads/phone_<UUID>.<ext>`; unique names never overwrite differing bytes. Max25MiB/file,100MiB total decoded attachments,150MiB serialized request. Preserve files across snapshots. Downloaded files remain available offline. No network fetching of external images for sync.

Initial pairing: if no local edits fetch Mac snapshot; if phone already has notes, present explicit Keep both to upload those under a new board. Don't wipe phone content automatically. Normal sync does POST when dirty and GET when clean. Persist snapshot and acknowledged revision together atomically; save phone edits before network. A failed write leaves local edits dirty. Disable editing during sync or reconcile edits made during the request so acknowledgment cannot erase them. Sync on foreground/reconnect where practical and provide manual pull-to-refresh/Sync now. No background-sync guarantees.
