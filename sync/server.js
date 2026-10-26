'use strict';
const express = require('express');
const https = require('node:https');
const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const { envelope, apply } = require('./workspace');
const stateDir = path.join(process.env.DATA_DIR || path.join(__dirname,'../data'),'sync');
function credentials({rotate=false}={}) {
  fs.mkdirSync(stateDir,{recursive:true,mode:0o700}); fs.chmodSync(stateDir,0o700);
  const keyFile=path.join(stateDir,'key.pem'), certFile=path.join(stateDir,'cert.pem'), tokenFile=path.join(stateDir,'token');
  if (!fs.existsSync(keyFile) || !fs.existsSync(certFile)) {
    execFileSync('/usr/bin/openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',keyFile,'-out',certFile,'-days','3650','-subj','/CN=Pinboard Mac'],{stdio:'ignore'});
    fs.chmodSync(keyFile,0o600); fs.chmodSync(certFile,0o600);
  }
  if (rotate || !fs.existsSync(tokenFile)) fs.writeFileSync(tokenFile,crypto.randomBytes(32).toString('base64url'),{mode:0o600});
  fs.chmodSync(tokenFile,0o600);
  const key=fs.readFileSync(keyFile),cert=fs.readFileSync(certFile),token=fs.readFileSync(tokenFile,'utf8').trim();
  const certificateSHA256=crypto.createHash('sha256').update(new crypto.X509Certificate(cert).raw).digest('hex');
  return {key,cert,token,certificateSHA256};
}
function authenticated(token, header) {
  const expected=Buffer.from('Bearer '+token),actual=Buffer.from(typeof header==='string'?header:'');
  return actual.length===expected.length && crypto.timingSafeEqual(actual,expected);
}
function createSyncApp(token) {
  const app=express(); app.disable('x-powered-by');
  app.use((req,res,next)=>{
    res.set({'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
    if (!authenticated(token,req.headers.authorization)) return res.status(401).json({error:'Pair this iPhone with your Mac first.'});
    if (req.headers.origin) return res.status(403).json({error:'Browser access is not supported.'});
    next();
  });
  app.use(express.json({limit:'150mb'}));
  app.get('/v1/health',(req,res)=>res.json({ok:true,protocol:1}));
  app.get('/v1/notebook',(req,res,next)=>{try {res.json(envelope());} catch(e){next(e);}});
  for (const route of ['notebook','recover']) app.post('/v1/'+route,(req,res,next)=>{
    try {
      if (typeof req.body?.baseRevision!=='string' || !/^[a-f0-9]{64}$/.test(req.body.baseRevision)) return res.status(400).json({error:'A current notebook revision is required.'});
      const result=apply(req.body.baseRevision,req.body.workspace,route==='recover');
      res.status(result.error==='conflict'?409:200).json(result);
    } catch(e){next(e);}
  });
  app.use((err,req,res,next)=>{res.status(err.status || 500).json({error:err.status?err.message:'Sync could not be saved. Your phone copy has not been acknowledged.'});});
  return app;
}
function addresses() {
  return [...new Set(Object.values(os.networkInterfaces()).flat().filter(n=>n && n.family==='IPv4' && !n.internal && /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/.test(n.address)).map(n=>n.address))];
}
function setupHandler(creds, syncPort, setupPort) {
  return (req,res)=>{
    res.setHeader('Cache-Control','no-store'); res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Content-Security-Policy',"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'");
    const expected=new Set(['127.0.0.1:'+setupPort,'localhost:'+setupPort]);
    if (!expected.has(req.headers.host) || (req.headers.origin && !['http://127.0.0.1:'+setupPort,'http://localhost:'+setupPort].includes(req.headers.origin)) || (req.headers['sec-fetch-site'] && !['none','same-origin'].includes(req.headers['sec-fetch-site']))) {res.writeHead(403);return res.end('Open setup directly on your Mac.');}
    if (req.method!=='GET') {res.writeHead(405);return res.end();}
    if (req.url==='/pairing') {
      res.setHeader('Content-Type','application/json');
      return res.end(JSON.stringify(addresses().map(address=>({version:1,url:'https://'+address+':'+syncPort,token:creds.token,certificateSHA256:creds.certificateSHA256}))));
    }
    if (req.url!=='/') {res.writeHead(404);return res.end();}
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.end(`<!doctype html><html lang="en"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Connect your iPhone · Pinboard</title><style>body{margin:0;background:#faf8f3;color:#2b302a;font:17px/1.55 system-ui}main{max-width:540px;margin:10vh auto;padding:28px}h1{font-size:32px;line-height:1.15;letter-spacing:-1px}button,select{font:inherit;padding:12px 18px;border-radius:12px;border:1px solid #c9cfc2;background:white}button{background:#3e6246;color:white;cursor:pointer}textarea{box-sizing:border-box;width:100%;min-height:170px;margin:16px 0;padding:14px;font:14px/1.5 system-ui;border:1px solid #c9cfc2;border-radius:12px}small{color:#5c655a}#status{min-height:1.6em}</style><main><small>PINBOARD / YOUR DEVICES</small><h1>A little notebook.<br>On both your devices.</h1><p>Connect your iPhone to the same Wi-Fi as this Mac. In the Pinboard iPhone app, open <strong>Sync settings</strong> and paste this connection card.</p><label for="address">Mac address</label> <select id="address"></select><textarea aria-label="Private connection card" id="card" readonly></textarea><button id="copy">Copy connection card</button><p id="status" role="status"></p><small>This card grants access to your notebook. Keep it private. Sync works while this Mac is running and reachable. To disconnect all phones, stop sync and run the revoke command in the setup guide.</small></main><script>let cards=[];const select=document.querySelector('#address'),card=document.querySelector('#card'),status=document.querySelector('#status');fetch('/pairing').then(r=>r.json()).then(data=>{cards=data;for(const c of data){const option=document.createElement('option');option.textContent=new URL(c.url).hostname;select.append(option)}if(!data.length){status.textContent='Connect your Mac to Wi-Fi, then reload this page.';document.querySelector('#copy').disabled=true;}else card.value=JSON.stringify(data[0]);}).catch(()=>status.textContent='Could not load connection details. Reload to try again.');select.onchange=()=>card.value=JSON.stringify(cards[select.selectedIndex]);document.querySelector('#copy').onclick=async()=>{try{await navigator.clipboard.writeText(card.value);status.textContent='Copied. Paste it into Pinboard on your iPhone.'}catch{card.select();status.textContent='Select and copy the connection card above.'}};</script></html>`);
  };
}
function start() {
  const creds=credentials({rotate:process.argv.includes('--revoke')});
  if (process.argv.includes('--revoke')) { console.log('Pairing credential replaced. Restart the sync service; previous phones must pair again.'); return; }
  const syncPort=Number(process.env.SYNC_PORT || 5198), setupPort=Number(process.env.SETUP_PORT || 5199);
  const secure=https.createServer({...creds,minVersion:'TLSv1.2',requestTimeout:60000},createSyncApp(creds.token));
  const setup=http.createServer(setupHandler(creds,syncPort,setupPort));
  for(const server of [secure,setup]) server.on('error',e=>{console.error('Pinboard sync could not start:',e.message);process.exit(1);});
  secure.listen(syncPort,'0.0.0.0',()=>console.log('Encrypted Pinboard sync is running on port '+syncPort+'.'));
  setup.listen(setupPort,'127.0.0.1',()=>console.log('Pair your iPhone on this Mac: http://127.0.0.1:'+setupPort));
}
if(require.main===module) start();
module.exports={createSyncApp,credentials,setupHandler,authenticated};
