'use strict';
const { db, stmt, id, rootCanvasId } = require('../db');
if(db.prepare('SELECT COUNT(*) AS n FROM items').get().n){console.log('Workspace already has content; nothing changed.');process.exit(0);}
const root=rootCanvasId();
const rootRow=stmt.getCanvas.get(root);rootRow.title='My workspace';stmt.updateCanvas.run(rootRow);
let z=0;
function item(type,data,x,y,parentItemId=null,color=null,canvasId=root,w=240){const it={id:id('i_'),canvasId,parentItemId,type,x,y,w,h:null,z:++z,color,data:JSON.stringify(data),createdAt:Date.now()};stmt.insertItem.run(it);return it.id;}
db.transaction(()=>{
  const a=item('column',{title:'Start here'},0,0,null,'pink',root,252);
  const b=item('column',{title:'Things to keep'},285,0,null,'green',root,252);
  const c=item('column',{title:'Ideas in motion'},570,0,null,'blue',root,252);
  item('note',{title:'Room to think',body:'A note, an image, a half-formed idea. Put it here, then give it a home.\n\nThis is a starter board. Everything here is yours to change.'},0,0,a,'yellow');
  item('todo',{title:'Make yourself at home',tasks:[{id:id('t_'),text:'Double-click a card to edit',done:false},{id:id('t_'),text:'Add a note from the toolbar',done:false},{id:id('t_'),text:'Drag a card into a column',done:false},{id:id('t_'),text:'Make a board for a project',done:false}]},0,1,a);
  item('image',{src:'/assets/coast.jpg',name:'A quieter kind of weekend',naturalW:800,naturalH:600},0,0,b);
  item('note',{title:'A small reminder',body:'Not every idea needs to become a project. Some things are just worth keeping.'},0,1,b);
  const child=id('c_');stmt.insertCanvas.run({id:child,title:'Weekend ideas',parentCanvasId:root,color:'green',icon:'leaf',createdAt:Date.now()});
  item('board',{childCanvasId:child},0,0,c,'green');
  item('link',{title:'A little inspiration',url:'https://www.thisiscolossal.com/'},0,1,c,'blue');
  item('note',{title:'A day without a schedule',body:'Find a new bookshop. Take the long way home. Bring a camera.'},30,30,null,'yellow',child);
})();
console.log('Created the editable starter board.');db.close();
