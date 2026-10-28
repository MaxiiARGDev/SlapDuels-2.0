import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createBridge} from '../bridge/server.mjs';
import {validate} from '../bridge/schema.mjs';
import {exportSelection,classify,cleanName} from '../figma/exporter.mjs';
const rect=(id,parent=null)=>({id,parent,name:id,class:'Frame',x:0,y:0,w:1,h:1,rotation:0,opacity:1,fillOpacity:1,color:[0,0,0],radius:0});
const packet=()=>({schema:1,sourceId:'fixture',name:'Test',width:400,height:300,nodes:[rect('root')],assets:{},warnings:[]});
test('schema rejects executable classes, duplicate IDs, missing parents and non-finite geometry',()=>{
 assert.equal(validate(packet()).schema,1);
 for(const mutate of [p=>p.nodes[0].class='Script',p=>p.nodes.push(rect('root')),p=>p.nodes[0].parent='missing',p=>p.nodes[0].w=NaN,p=>p.nodes[0].opacity=2,p=>p.nodes.push(rect('second')),p=>p.nodes[0].asset='missing']){
  const p=packet();mutate(p);assert.throws(()=>validate(p));
 }
});
test('exporter preserves text, geometry, tags and raster output',async()=>{
 assert.equal(cleanName('Buy [button]'),'Buy');assert.equal(classify({name:'Buy [button]',type:'FRAME'}),'TextButton');
 const text={id:'text',name:'Coins [dynamic]',type:'TEXT',x:20,y:30,width:100,height:40,characters:'123',fontName:{family:'Gotham'},fontSize:20,textAlignHorizontal:'RIGHT',fills:[{type:'SOLID',color:{r:1,g:1,b:1}}]};
 const art={id:'art',name:'Star',type:'VECTOR',x:0,y:0,width:20,height:20};
 const root={id:'root',name:'Menu',type:'FRAME',width:400,height:300,children:[text,art],layoutMode:'VERTICAL'};
 const png=new Uint8Array([137,80,78,71,13,10,26,10]);
 const p=await exportSelection(root,'source',async()=>png);
 assert.equal(p.nodes[1].text,'123');assert.equal(p.nodes[1].x,.05);assert.equal(p.nodes[1].align,'Right');assert.equal(p.nodes[2].class,'ImageLabel');assert.deepEqual(p.assets.art.bytes,Array.from(png));assert.ok(p.warnings.some(w=>w.includes('Auto Layout')));validate(p);
});
test('explicit image IDs do not require upload',async()=>{
 const p=await exportSelection({id:'a',name:'Icon [asset=123]',type:'RECTANGLE',width:10,height:10},'x',async()=>{throw Error('No raster needed');});
 assert.equal(p.nodes[0].assetId,'123');assert.equal(p.nodes[0].class,'ImageLabel');
});
test('local bridge authentication, persistence, revisions, image mapping and rejection',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'ui-bridge-test-'));const b=await createBridge({directory:dir,token:'test-secret'});
 await new Promise(resolve=>b.server.listen(0,'127.0.0.1',resolve));const url='http://127.0.0.1:'+b.server.address().port;
 const call=(path,body,token='test-secret')=>fetch(url+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
 try{
  assert.equal((await call('/design',null,'wrong')).status,401);assert.equal((await call('/design')).status,404);
  let p=packet();assert.equal((await call('/design',p)).status,200);
  let r=await(await call('/design')).json();assert.equal(r.revision,1);assert.equal(r.packet.name,'Test');
  p.nodes.push({...rect('image','root'),class:'ImageLabel',asset:'image'});p.assets.image={name:'Image',bytes:[137,80,78,71,13,10,26,10]};
  assert.equal((await call('/design',p)).status,200);r=await(await call('/status')).json();const hash=r.assets.image.hash;
  assert.deepEqual([...await readFile(join(dir,'assets',hash+'.png'))],p.assets.image.bytes);
  assert.equal((await call('/mapping',{[hash]:'123456'})).status,200);
  r=await(await call('/design')).json();assert.equal(r.packet.nodes[1].assetId,'123456');assert.equal(r.revision,3);assert.equal(r.packet.assets.image.bytes,undefined);
  assert.equal((await call('/mapping',{'../../bad':'1'})).status,400);
  assert.equal((await call('/design',{...packet(),nodes:[{...rect('root'),class:'LocalScript'}]})).status,400);
  assert.equal((await(await call('/design')).json()).revision,3);
  await call('/design',p);assert.equal((await(await call('/design')).json()).packet.nodes[1].assetId,'123456');
  const restored=await createBridge({directory:dir,token:'other'});assert.ok(restored);restored.server.close();
 }finally{await new Promise(resolve=>b.server.close(resolve));await rm(dir,{recursive:true,force:true});}
});
