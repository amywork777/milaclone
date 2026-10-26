'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { db, stmt, id, rootCanvasId } = require('../db');
const uploadDir = process.env.UPLOAD_DIR || path.join(__dirname, '../public/uploads');
const assetDir = process.env.ASSET_DIR || path.join(__dirname, '../public/assets');
const backupDir = path.join(process.env.DATA_DIR || path.join(__dirname, '../data'), 'sync/backups');
const MAX_FILE = 25 * 1024 * 1024, MAX_TOTAL = 100 * 1024 * 1024;
const canonical = value => JSON.stringify(sort(value));
function sort(value) {
  if (Array.isArray(value)) return value.map(sort);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, sort(value[k])]));
  return value;
}
function revision(workspace) {
  const normalized = { ...workspace, canvases: [...workspace.canvases].sort((a,b)=>a.id.localeCompare(b.id)), items: [...workspace.items].sort((a,b)=>a.id.localeCompare(b.id)) };
  return crypto.createHash('sha256').update(canonical(normalized)).digest('hex');
}
function fail(message) { const e = new Error(message); e.status = 400; throw e; }
function filePath(src) {
  const match = /^\/(uploads|assets)\/([a-zA-Z0-9_-][a-zA-Z0-9_.-]{0,199})$/.exec(src);
  if (!match || match[2].includes('..')) fail('Invalid attachment path');
  return path.join(match[1] === 'uploads' ? uploadDir : assetDir, match[2]);
}
function referenced(workspace) { return new Set(workspace.items.map(i=>i.data.src).filter(src=>typeof src==='string' && src.startsWith('/'))); }
function readWorkspace() {
  const workspace = {
    rootCanvasId: rootCanvasId(),
    canvases: db.prepare('SELECT * FROM canvases ORDER BY id').all(),
    items: db.prepare('SELECT * FROM items ORDER BY id').all().map(it=>({...it, data:JSON.parse(it.data || '{}')})),
    files: {}
  };
  let size = 0;
  for (const src of referenced(workspace)) {
    const file = filePath(src);
    if (!fs.existsSync(file)) continue; // Existing broken links stay visible, never fetch remote files.
    const stat = fs.lstatSync(file);
    if (!stat.isFile() || stat.isSymbolicLink()) fail('Attachment is not a regular file');
    if (stat.size > MAX_FILE || (size += stat.size) > MAX_TOTAL) fail('Notebook attachments exceed sync limits');
    workspace.files[src] = fs.readFileSync(file).toString('base64');
  }
  return workspace;
}
function envelope() { const workspace = db.transaction(readWorkspace)(); return {revision:revision(workspace), workspace}; }
function validate(w) {
  if (!w || typeof w !== 'object' || !Array.isArray(w.canvases) || !Array.isArray(w.items) || !w.files || typeof w.files !== 'object' || Array.isArray(w.files)) fail('Invalid notebook');
  if (w.canvases.length > 10000 || w.items.length > 50000) fail('Notebook is too large');
  const validId = s=>typeof s==='string' && /^[a-zA-Z0-9_-]{1,100}$/.test(s);
  const nullableText = s=>s===null || (typeof s==='string' && s.length<=1000);
  const time = n=>Number.isSafeInteger(n) && n>=0;
  const canvases = new Map(), items = new Map();
  for (const c of w.canvases) {
    if (!validId(c.id) || canvases.has(c.id) || typeof c.title!=='string' || c.title.length>10000 || !nullableText(c.color) || !nullableText(c.icon) || !time(c.createdAt)) fail('Invalid board');
    canvases.set(c.id,c);
  }
  if (!canvases.has(w.rootCanvasId)) fail('Root board is missing');
  for (const c of canvases.values()) {
    if (c.id===w.rootCanvasId ? c.parentCanvasId!==null : !canvases.has(c.parentCanvasId)) fail('Invalid board parent');
    const seen = new Set([c.id]); let parent=c.parentCanvasId;
    while (parent!==null) { if (seen.has(parent)) fail('Board cycle'); seen.add(parent); parent=canvases.get(parent)?.parentCanvasId; if (parent===undefined) fail('Missing board parent'); }
  }
  const types = new Set(['note','link','todo','image','file','board','column','comment']);
  for (const it of w.items) {
    if (!validId(it.id) || items.has(it.id) || !canvases.has(it.canvasId) || !types.has(it.type) || !nullableText(it.color) || !time(it.createdAt)) fail('Invalid card');
    if (!['x','y','w','z'].every(k=>Number.isFinite(it[k]) && Math.abs(it[k])<=1e8) || !(it.h===null || (Number.isFinite(it.h) && Math.abs(it.h)<=1e8))) fail('Invalid card position');
    if (!it.data || typeof it.data!=='object' || Array.isArray(it.data)) fail('Invalid card content');
    items.set(it.id,it);
  }
  const owned = new Set();
  for (const it of items.values()) {
    if (it.parentItemId!==null) {
      const parent=items.get(it.parentItemId);
      if (!parent || parent.type!=='column' || parent.canvasId!==it.canvasId || it.type==='column') fail('Invalid card group');
    }
    if (it.type==='board') {
      const child=canvases.get(it.data.childCanvasId);
      if (!child || child.parentCanvasId!==it.canvasId || owned.has(child.id)) fail('Invalid nested board');
      owned.add(child.id);
    }
    for (const k of ['title','body','url','src','name','mime']) if (it.data[k]!==undefined && typeof it.data[k]!=='string') fail('Invalid card text');
    if (it.data.tasks!==undefined && (!Array.isArray(it.data.tasks) || it.data.tasks.some(t=>!t || typeof t!=='object' || typeof t.text!=='string' || typeof t.done!=='boolean'))) fail('Invalid tasks');
  }
  if (owned.size!==canvases.size-1) fail('Unreachable board');
  const refs=referenced(w); let size=0;
  const previousRefs = new Set(db.prepare('SELECT data FROM items').all().map(it=>JSON.parse(it.data || '{}').src));
  for (const src of refs) {
    const file = filePath(src);
    if (!Object.hasOwn(w.files, src) && !fs.existsSync(file) && !previousRefs.has(src)) fail('New attachment bytes are missing');
  }
  for (const [src, encoded] of Object.entries(w.files)) {
    filePath(src);
    if (!refs.has(src)) fail('Unreferenced attachment');
    if (typeof encoded!=='string' || encoded.length>Math.ceil(MAX_FILE/3)*4 || encoded.length%4 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) fail('Invalid attachment bytes');
    const bytes=Buffer.from(encoded,'base64');
    if (bytes.length>MAX_FILE || (size+=bytes.length)>MAX_TOTAL) fail('Notebook attachments exceed sync limits');
    const file=filePath(src);
    if (fs.existsSync(file)) {
      if (fs.lstatSync(file).isSymbolicLink() || !fs.lstatSync(file).isFile() || !fs.readFileSync(file).equals(bytes)) fail('Attachment name already has different content');
    } else if (src.startsWith('/assets/')) fail('New attachments must use uploads');
  }
  return w;
}
function persistFiles(w) {
  fs.mkdirSync(uploadDir,{recursive:true});
  for (const [src, encoded] of Object.entries(w.files)) {
    const file=filePath(src);
    if (!fs.existsSync(file)) fs.writeFileSync(file,Buffer.from(encoded,'base64'),{flag:'wx',mode:0o600});
  }
}
function replace(w) {
  db.prepare('DELETE FROM items').run(); db.prepare('DELETE FROM canvases').run();
  for (const c of w.canvases) stmt.insertCanvas.run(c);
  for (const it of w.items) stmt.insertItem.run({...it,data:JSON.stringify(it.data)});
  stmt.setMeta.run('rootCanvasId', w.rootCanvasId);
  stmt.setMeta.run('syncEpoch', crypto.randomUUID());
}
function recover(current, phone) {
  const canvasIds=new Map(phone.canvases.map(c=>[c.id,id('c_')]));
  const itemIds=new Map(phone.items.map(it=>[it.id,id('i_')]));
  const canvases=phone.canvases.map(c=>({...c,id:canvasIds.get(c.id),parentCanvasId:c.parentCanvasId?canvasIds.get(c.parentCanvasId):current.rootCanvasId,title:c.id===phone.rootCanvasId?'From iPhone · '+new Date().toLocaleDateString('en-US'):c.title}));
  const items=phone.items.map(it=>({...it,id:itemIds.get(it.id),canvasId:canvasIds.get(it.canvasId),parentItemId:it.parentItemId?itemIds.get(it.parentItemId):null,data:it.type==='board'?{...it.data,childCanvasId:canvasIds.get(it.data.childCanvasId)}:it.data}));
  items.push({id:id('i_'),canvasId:current.rootCanvasId,parentItemId:null,type:'board',x:60,y:60,w:240,h:null,z:Math.max(0,...current.items.map(i=>i.z))+1,color:'yellow',data:{childCanvasId:canvasIds.get(phone.rootCanvasId)},createdAt:Date.now()});
  return {...current,canvases:[...current.canvases,...canvases],items:[...current.items,...items],files:{...current.files,...phone.files}};
}
function apply(baseRevision, input, keepBoth=false) {
  validate(input);
  // BEGIN IMMEDIATE holds the SQLite writer lock across CAS and replacement,
  // including edits arriving from the separate localhost web process.
  return db.transaction(()=>{
    const current=envelope();
    const inputRevision=revision(input);
    const receiptKey='syncReceipt:'+crypto.createHash('sha256').update(JSON.stringify([baseRevision,inputRevision,keepBoth])).digest('hex');
    const receipt=stmt.getMeta.get(receiptKey)?.value;
    // A durable receipt acknowledges this exact operation even after later Mac
    // edits. Re-importing a recovery after a lost response would duplicate boards.
    if (receipt || (!keepBoth && inputRevision===current.revision)) return current;
    if (baseRevision!==current.revision) return {error:'conflict',...current};
    const next=keepBoth?recover(current.workspace,input):input;
    validate(next);
    fs.mkdirSync(backupDir,{recursive:true,mode:0o700});
    fs.writeFileSync(path.join(backupDir,Date.now()+'-'+crypto.randomUUID()+'.json'),JSON.stringify(current),{flag:'wx',mode:0o600});
    persistFiles(next); replace(next);
    const result=envelope(); stmt.setMeta.run(receiptKey,result.revision);
    return result;
  }).immediate();
}
module.exports={envelope,apply,validate,revision,filePath,MAX_FILE,MAX_TOTAL};
