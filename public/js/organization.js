import { api } from './api.js';
import { state, dom, elMap } from './state.js';
import { openCanvas } from './main.js';
import { render } from './cards.js';
import { applyCam } from './viewport.js';
import { flushPendingSaves, select } from './editing.js';
import { refreshIcons, toast } from './util.js';

let workspace, updateTimer;
const byId = id => document.getElementById(id);
const escape = value => String(value || '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

export async function updateOrganization() {
  try {
    workspace = await api.workspace();
    const tree = byId('boardTree'); tree.replaceChildren();
    const visit = (parent, depth) => {
      for (const canvas of workspace.canvases.filter(c=>c.parentCanvasId===parent)) {
        const button = document.createElement('button');
        button.className = canvas.id===state.view.canvas?.id?'current':'';
        button.style.setProperty('--depth',Math.min(depth,6));
        button.innerHTML='<i data-lucide="layout-dashboard"></i><span></span>';
        button.querySelector('span').textContent=canvas.title;
        button.title=canvas.title;
        if(canvas.id===state.view.canvas?.id)button.setAttribute('aria-current','page');
        button.onclick=()=>{closeSidebar();openCanvas(canvas.id);};tree.append(button);visit(canvas.id,depth+1);
      }
    };visit(null,0);refreshIcons(tree);
    const title=byId('personalTitle');if(document.activeElement!==title)title.value=state.view.canvas?.title||'';
    const count=state.view.items.filter(it=>it.type!=='column').length;
    byId('personalCount').textContent=count+(count===1?' card':' cards');
    for(const menu of document.querySelectorAll('.move-to'))for(const option of menu.options){
      const column=state.view.items.find(it=>it.id===option.value);if(column)option.textContent=column.data.title||'Column';
    }
    byId('undoAction').disabled=!workspace.canUndo;byId('redoAction').disabled=!workspace.canRedo;
  } catch { toast('Could not load your board list. Check that Pinboard is running.'); }
}
function refreshSoon(){clearTimeout(updateTimer);updateTimer=setTimeout(updateOrganization,150);}
function closeSidebar(){byId('boardSidebar').classList.remove('open');byId('sidebarVeil').hidden=true;}
function dialog(content){
  document.querySelector('.personal-overlay')?.remove();const overlay=document.createElement('div');overlay.className='personal-overlay';
  const panel=document.createElement('section');panel.className='personal-dialog';panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.innerHTML=content;overlay.append(panel);document.body.append(overlay);
  const previous=document.activeElement;
  const close=()=>{overlay.remove();document.removeEventListener('keydown',key);previous?.focus();};
  const key=e=>{if(e.key==='Escape'){e.stopImmediatePropagation();close();}if(e.key==='Tab'){const items=[...panel.querySelectorAll('button,input,a,select')].filter(el=>!el.disabled);if(!items.length)return;const index=items.indexOf(document.activeElement);if(e.shiftKey&&index<=0){e.preventDefault();items.at(-1).focus();}else if(!e.shiftKey&&index===items.length-1){e.preventDefault();items[0].focus();}}};
  document.addEventListener('keydown',key);overlay.onclick=e=>{if(e.target===overlay)close();};panel.querySelectorAll('[data-close]').forEach(b=>b.onclick=close);panel.querySelector('input,button')?.focus();return {panel,close};
}
async function newBoard(){
  const {panel,close}=dialog('<h2>New board</h2><form><input aria-label="New board name" name="title" placeholder="What are you thinking about?" maxlength="200" required><div class="dialog-actions"><button type="button" data-close>Cancel</button><button class="confirm" type="submit">Create board</button></div></form>');
  panel.querySelector('form').onsubmit=async e=>{e.preventDefault();const title=panel.querySelector('input').value.trim();if(!title)return;await flushPendingSaves();const it=await api.create({canvasId:state.view.canvas.id,type:'board',x:40,y:40,w:152,data:{title}});close();await openCanvas(it.data.childCanvasId);};
}
async function search(){
  await flushPendingSaves();workspace=await api.workspace();
  const {panel,close}=dialog('<h2>Find anything</h2><input aria-label="Search all boards" placeholder="A note, a link, a thought…"><div id="allSearchResults"></div><div class="dialog-actions"><button data-close>Close</button></div>');
  const input=panel.querySelector('input'),results=panel.querySelector('#allSearchResults');
  const display=()=>{const q=input.value.trim().toLowerCase();results.replaceChildren();const hits=[];
    for(const c of workspace.canvases)if(!q||c.title.toLowerCase().includes(q))hits.push({title:c.title,subtitle:'Board',canvasId:c.id});
    if(q)for(const it of workspace.items){if(it.type==='board')continue;const d=it.data;const text=[d.title,d.body,d.url,d.name,...(d.tasks||[]).map(t=>t.text)].join(' ').toLowerCase();if(text.includes(q)){const c=workspace.canvases.find(c=>c.id===it.canvasId);hits.push({title:d.title||d.name||d.body?.slice(0,70)||it.type,subtitle:(c?.title||'Board')+' · '+it.type,canvasId:it.canvasId,id:it.id});}}
    for(const hit of hits.slice(0,60)){const button=document.createElement('button');button.className='search-hit';button.innerHTML=`${escape(hit.title)}<small>${escape(hit.subtitle)}</small>`;button.onclick=async()=>{close();await openCanvas(hit.canvasId);if(hit.id){select(hit.id);state.cam={x:0,y:0,scale:1};applyCam();const card=elMap.get(hit.id);if(card){const rect=card.getBoundingClientRect(),stage=dom.stage.getBoundingClientRect();state.cam.x=stage.width/2-(rect.left-stage.left+rect.width/2);state.cam.y=stage.height/2-(rect.top-stage.top+Math.min(rect.height,stage.height-40)/2);applyCam();card.focus({preventScroll:true});}}};results.append(button);}
    if(!hits.length)results.innerHTML='<p class="personal-empty">No matches. Try another word.</p>';
  };input.oninput=display;display();
}
async function undo(direction='undo'){
  await flushPendingSaves();const result=await api.history(direction);if(!result.ok)return;await openCanvas(state.view.canvas.id);toast(direction==='undo'?'Undone':'Redone');
}
async function tidy(){
  await flushPendingSaves();const items=state.view.items.filter(it=>!it.parentItemId&&!it.data.locked);
  const width=Math.max(550,dom.stage.clientWidth-65);let x=25,y=25,rowHeight=0;const updates=[];
  const locked=state.view.items.filter(it=>!it.parentItemId&&it.data.locked);
  if(locked.length)y=Math.max(...locked.map(it=>it.y+(elMap.get(it.id)?.offsetHeight||180)))+30;
  for(const it of items){const w=it.w||240,h=elMap.get(it.id)?.offsetHeight||180;if(x+w>width&&x>25){x=25;y+=rowHeight+25;rowHeight=0;}updates.push({id:it.id,x,y});x+=w+25;rowHeight=Math.max(rowHeight,h);}
  await api.patchMany(updates);dom.world.classList.add('tidying');for(const u of updates){Object.assign(state.view.items.find(it=>it.id===u.id),u);const el=elMap.get(u.id);if(el){el.style.left=u.x+'px';el.style.top=u.y+'px';}}
  state.cam={x:30,y:25,scale:1};applyCam();setTimeout(()=>dom.world.classList.remove('tidying'),350);toast('Cards arranged. Your columns stay together.');
}
function fit(){const items=state.view.items.filter(it=>!it.parentItemId);if(!items.length)return;const minX=Math.min(...items.map(it=>it.x)),minY=Math.min(...items.map(it=>it.y));const maxX=Math.max(...items.map(it=>it.x+(it.w||240))),maxY=Math.max(...items.map(it=>it.y+(elMap.get(it.id)?.offsetHeight||180)));const scale=Math.min(1,(dom.stage.clientWidth-70)/(maxX-minX),(dom.stage.clientHeight-65)/(maxY-minY));state.cam={x:35-minX*scale,y:30-minY*scale,scale:Math.max(.2,scale)};applyCam();}
async function exportBackup(){await flushPendingSaves();location.href='/api/backup';}
function help(){dialog('<h2>Your space, with a little structure</h2><p>Choose a tool, then click the canvas to place it. Double-click a card to edit it. Drag cards into columns to keep related things together.</p><p>Make boards inside boards for bigger projects. Find anything searches across all of them. Tidy up arranges loose cards and leaves locked cards in place.</p><p><strong>Everything saves on this Mac.</strong> Export backup includes your notes and uploaded files. Undo is available while the app server stays running.</p><p>Keyboard: ⌘ / Ctrl K to search, ⌘ / Ctrl Z to undo, N for a new note. Focus a card and press Enter to edit or open it.</p><div class="dialog-actions"><button data-close>Got it</button></div>');}
export function initOrganization(){
  byId('newPersonalBoard').onclick=newBoard;byId('findAnything').onclick=search;byId('backupButton').onclick=exportBackup;byId('exportBtn').onclick=exportBackup;byId('personalHelp').onclick=help;
  byId('undoAction').onclick=()=>undo();byId('redoAction').onclick=()=>undo('redo');byId('tidyAction').onclick=tidy;byId('fitAction').onclick=fit;
  byId('personalTitle').onchange=async e=>{const title=e.target.value.trim()||'Untitled board';await api.patchCanvas(state.view.canvas.id,{title});await openCanvas(state.view.canvas.id);};
  byId('mobileFind').onclick=()=>{byId('msheet').hidden=true;search();};byId('mobileBoards').onclick=()=>{byId('msheet').hidden=true;byId('boardSidebar').classList.add('open');byId('sidebarVeil').hidden=false;};byId('mobileTidy').onclick=()=>{byId('msheet').hidden=true;tidy();};byId('mobileUndo').onclick=()=>{byId('msheet').hidden=true;undo();};byId('sidebarVeil').onclick=closeSidebar;
  window.addEventListener('workspace-changed',refreshSoon);
  document.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='k'){e.preventDefault();search();}if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='z'&&!e.target.matches('input,textarea,[contenteditable=true]')){e.preventDefault();undo(e.shiftKey?'redo':'undo');}});
  window.addEventListener('unhandledrejection',e=>{byId('saveStatus').textContent='Could not save. Keep this tab open.';toast(e.reason?.message||'Something could not be saved. Check the app is running.');});
}
