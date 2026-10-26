'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const https=require('node:https');
const http=require('node:http');
const crypto=require('node:crypto');
const TMP=fs.mkdtempSync(path.join(os.tmpdir(),'pinboard-sync-'));
process.env.DATA_DIR=TMP;
process.env.UPLOAD_DIR=path.join(TMP,'uploads');
process.env.ASSET_DIR=path.join(TMP,'assets');
const {db,stmt,id}=require('../db');
const {envelope,apply,revision,validate}=require('../sync/workspace');
const {createSyncApp,credentials,setupHandler}=require('../sync/server');
let server,setup,base,creds;
function note(w,title='Phone thought') {
  w.items.push({id:id('i_'),canvasId:w.rootCanvasId,parentItemId:null,type:'note',x:60,y:80,w:240,h:null,z:1,color:null,data:{title,body:'A small idea',extra:{preserve:true}},createdAt:Date.now()});return w;
}
function request(route,body,token=creds.token) {
  return new Promise((resolve,reject)=>{
    const req=https.request(base+route,{method:body?'POST':'GET',ca:creds.cert,checkServerIdentity:(host,cert)=>{if(crypto.createHash('sha256').update(cert.raw).digest('hex')!==creds.certificateSHA256)return new Error('Wrong certificate');},headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})}},res=>{let data='';res.on('data',v=>data+=v);res.on('end',()=>resolve({status:res.statusCode,body:JSON.parse(data)}));});req.on('error',reject);if(body)req.write(JSON.stringify(body));req.end();
  });
}
test.before(async()=>{
  creds=credentials();server=https.createServer(creds,createSyncApp(creds.token));
  await new Promise(r=>server.listen(0,'127.0.0.1',r));base='https://127.0.0.1:'+server.address().port;
});
test.after(async()=>{await new Promise(r=>server.close(r));if(setup)await new Promise(r=>setup.close(r));db.close();fs.rmSync(TMP,{recursive:true,force:true});});
test('HTTPS requires a paired bearer token before serving notebook or parsing writes',async()=>{
  assert.equal((await request('/v1/notebook',null,'wrong')).status,401);
  assert.equal((await request('/v1/notebook',{workspace:{}},'wrong')).status,401);
  assert.deepEqual((await request('/v1/health')).body,{ok:true,protocol:1});
  assert.equal(fs.statSync(path.join(TMP,'sync/token')).mode & 0o777,0o600);
  assert.equal(credentials().certificateSHA256,creds.certificateSHA256);
});
test('sync saves offline edits and an identical retry is idempotent',async()=>{
  const before=envelope(),workspace=note(structuredClone(before.workspace));
  const first=await request('/v1/notebook',{baseRevision:before.revision,workspace});assert.equal(first.status,200);
  assert.equal(first.body.workspace.items.at(-1).data.extra.preserve,true);
  const again=await request('/v1/notebook',{baseRevision:before.revision,workspace});assert.equal(again.status,200);assert.equal(again.body.revision,first.body.revision);
  assert.ok(fs.readdirSync(path.join(TMP,'sync/backups')).length);
});
test('Mac edits after a phone snapshot cause conflict and preserve both inputs',async()=>{
  const before=envelope(),phone=note(structuredClone(before.workspace),'Offline');
  const first=stmt.getItem.get(before.workspace.items[0].id);first.data=JSON.stringify({title:'Changed on Mac'});stmt.updateItem.run(first);
  const mac=envelope(),result=await request('/v1/notebook',{baseRevision:before.revision,workspace:phone});
  assert.equal(result.status,409);assert.equal(result.body.revision,mac.revision);assert.equal(envelope().revision,mac.revision);
  assert.ok(phone.items.some(i=>i.data.title==='Offline'));
});
test('keep both remaps board and column IDs, preserves tasks and attachments, retries safely',async()=>{
  const before=envelope(),phone=structuredClone(before.workspace);
  const child=id('c_'),group=id('i_');
  phone.canvases.push({id:child,title:'Trip',parentCanvasId:phone.rootCanvasId,color:null,icon:null,createdAt:Date.now()});
  const template={parentItemId:null,x:50,y:50,w:240,h:null,z:1,color:null,createdAt:Date.now()};
  phone.items.push({...template,id:id('i_'),canvasId:phone.rootCanvasId,type:'board',data:{childCanvasId:child}});
  phone.items.push({...template,id:group,canvasId:child,type:'column',data:{title:'Before we go'}});
  phone.items.push({...template,id:id('i_'),canvasId:child,parentItemId:group,type:'todo',data:{tasks:[{id:'t',text:'Tickets',done:false,note:'Window seat',starred:true}]}});
  phone.items.push({...template,id:id('i_'),canvasId:child,type:'file',data:{src:'/uploads/phone_test.txt',name:'hello.txt',mime:'text/plain'}});
  phone.files['/uploads/phone_test.txt']=Buffer.from('offline attachment').toString('base64');
  const result=await request('/v1/recover',{baseRevision:before.revision,workspace:phone});assert.equal(result.status,200);
  assert.equal(result.body.workspace.items.length,before.workspace.items.length+phone.items.length+1);
  const imported=result.body.workspace.canvases.find(c=>c.title.startsWith('From iPhone'));
  assert.equal(imported.parentCanvasId,before.workspace.rootCanvasId);
  const tasks=result.body.workspace.items.find(i=>i.type==='todo');assert.equal(tasks.data.tasks[0].note,'Window seat');
  assert.ok(result.body.workspace.items.find(i=>i.id===tasks.parentItemId));
  assert.equal(fs.readFileSync(path.join(TMP,'uploads/phone_test.txt'),'utf8'),'offline attachment');
  const retry=await request('/v1/recover',{baseRevision:before.revision,workspace:phone});assert.equal(retry.status,200);assert.equal(retry.body.revision,result.body.revision);
  const edited=stmt.getCanvas.get(before.workspace.rootCanvasId);edited.title='A later Mac edit';stmt.updateCanvas.run(edited);
  const later=envelope();
  const lostAckRetry=await request('/v1/recover',{baseRevision:before.revision,workspace:phone});
  assert.equal(lostAckRetry.status,200);assert.equal(lostAckRetry.body.revision,later.revision);
  assert.equal(lostAckRetry.body.workspace.canvases.length,result.body.workspace.canvases.length);
});
test('CAS handles deletion and refuses resurrection from a stale phone',async()=>{
  const before=envelope(),deleted=structuredClone(before.workspace);deleted.items=deleted.items.filter(i=>i.type!=='note');
  const first=apply(before.revision,deleted);assert.ok(!first.error);
  assert.equal(apply(before.revision,before.workspace).error,'conflict');
  assert.equal(envelope().workspace.items.filter(i=>i.type==='note').length,0);
});
test('rejects path traversal, attachment collision, invalid graphs and malformed tasks without changing DB',()=>{
  const before=envelope();
  for (const change of [
    w=>{w.files['/uploads/../../secret']='YQ==';},
    w=>{w.files['/uploads/phone_test.txt']='Yg==';},
    w=>{w.canvases[0].parentCanvasId=w.canvases[0].id;},
    w=>{w.items[0].parentItemId='missing';},
    w=>{w.items[0].x=Infinity;},
    w=>{w.items[0].data.tasks=[{text:3,done:false}];},
    w=>{w.items[0].data.src='/uploads/missing_new_file.jpg';}
  ]) {const w=structuredClone(before.workspace);change(w);assert.throws(()=>apply(before.revision,w));assert.equal(envelope().revision,before.revision);}
});
test('revision is stable across object key and record ordering',()=>{
  const current=envelope();const reordered=structuredClone(current.workspace);reordered.items.reverse();reordered.canvases.reverse();assert.equal(revision(reordered),current.revision);
});
test('localhost pairing rejects hostile Host/Origin and only discloses card to local page',async()=>{
  setup=http.createServer();await new Promise(r=>setup.listen(0,'127.0.0.1',r));
  const port=setup.address().port;setup.on('request',setupHandler(creds,5198,port));
  const url='http://127.0.0.1:'+port;
  const hostileHost = await new Promise((resolve,reject)=>{const req=http.get(url+'/pairing',{headers:{Host:'evil.example'}},res=>{res.resume();resolve(res.statusCode);});req.on('error',reject);});
  assert.equal(hostileHost,403);
  assert.equal((await fetch(url+'/pairing',{headers:{Origin:'https://evil.example'}})).status,403);
  assert.equal((await fetch(url+'/pairing',{headers:{'Sec-Fetch-Site':'cross-site'}})).status,403);
  const result=await fetch(url+'/pairing');assert.equal(result.status,200);assert.equal(result.headers.get('cache-control'),'no-store');
  assert.equal((await fetch(url)).status,200);
});
test('external sync clears browser undo and rejects stale writes',async()=>{
  const express=require('express'),app=express();app.use(express.json());app.use(require('../workspace-routes'));
  const local=await new Promise(r=>{const s=app.listen(0,'127.0.0.1',()=>r(s));});
  try {
    const url='http://127.0.0.1:'+local.address().port;
    const page=await fetch(url+'/api/workspace'),epoch=page.headers.get('x-pinboard-epoch');
    const headers={'Content-Type':'application/json','X-Pinboard-Epoch':epoch};
    const originalGet=stmt.getCanvas.get;let lockHeld=false;
    stmt.getCanvas.get=function(...args){lockHeld=db.inTransaction;return originalGet.apply(this,args);};
    try { await fetch(url+'/api/item',{method:'POST',headers,body:JSON.stringify({canvasId:envelope().workspace.rootCanvasId,type:'note'})}); }
    finally {stmt.getCanvas.get=originalGet;}
    assert.equal(lockHeld,true,'content route must execute under the epoch writer lock');
    assert.ok((await(await fetch(url+'/api/workspace')).json()).canUndo);
    const before=envelope();apply(before.revision,note(structuredClone(before.workspace),'New from phone'));
    assert.equal((await fetch(url+'/api/history/undo',{method:'POST',headers})).status,409);
    assert.equal((await(await fetch(url+'/api/workspace')).json()).canUndo,false);
    assert.ok(envelope().workspace.items.some(i=>i.data.title==='New from phone'));
  } finally {await new Promise(r=>local.close(r));}
});
