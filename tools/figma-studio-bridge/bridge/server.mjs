import http from 'node:http';
import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {mkdir,readFile,writeFile,rename} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {validate} from './schema.mjs';

export async function createBridge({directory=resolve(fileURLToPath(new URL('../.local',import.meta.url))),token=randomBytes(24).toString('hex')}={}){
 await mkdir(join(directory,'assets'),{recursive:true});let state={revision:0,packet:null,mapping:{}};
 try{state=JSON.parse(await readFile(join(directory,'state.json'),'utf8'));if(state.packet)validate(state.packet);}catch(e){if(e.code!=='ENOENT')throw Error('Estado local inválido: conservado para recuperación');}
 let queue=Promise.resolve();
 async function commit(next){const file=join(directory,'state.tmp');await writeFile(file,JSON.stringify(next));await rename(file,join(directory,'state.json'));state=next;}
 const server=http.createServer(async(req,res)=>{
  res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','authorization,content-type');res.setHeader('Access-Control-Allow-Methods','GET,POST,OPTIONS');res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
  const send=(status,obj)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(obj));};
  try{
   if(!/^(localhost|127\.0\.0\.1)(:\d+)?$/.test(req.headers.host||''))return send(403,{error:'Host no permitido'});
   if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
   const path=new URL(req.url,'http://localhost').pathname;
   if(path==='/'&&req.method==='GET'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(await readFile(new URL('dashboard.html',import.meta.url)));return;}
   const candidate=Buffer.from(req.headers.authorization||'');const expected=Buffer.from('Bearer '+token);
   if(candidate.length!==expected.length||!timingSafeEqual(candidate,expected))return send(401,{error:'Token incorrecto'});
   if(path==='/design'&&req.method==='GET'){
    await queue;const p=structuredClone(state.packet);if(!p)return send(404,{error:'Exportá primero desde Figma'});
    for(const n of p.nodes)if(n.asset){const hash=p.assets[n.asset]?.hash;if(state.mapping[hash])n.assetId=state.mapping[hash];}
    return send(200,{revision:state.revision,packet:p});
   }
   if(path==='/status'&&req.method==='GET')return send(200,{revision:state.revision,name:state.packet?.name||null,assets:state.packet?.assets||{},mapping:state.mapping,assetDirectory:join(directory,'assets')});
   if(req.method!=='POST'||!['/design','/mapping'].includes(path))return send(404,{error:'Ruta inexistente'});
   if(!String(req.headers['content-type']).startsWith('application/json'))return send(415,{error:'Se requiere JSON'});
   let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>90*1024*1024){send(413,{error:'Archivo demasiado grande'});return;}chunks.push(chunk);}
   const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
   // Serialize all state mutations, including writes to disk.
   const work=queue.then(async()=>{
    if(path==='/mapping'){
     if(!body||typeof body!=='object'||Array.isArray(body))throw Error('Mapa inválido');
     const mapping={...state.mapping};const known=new Set(Object.values(state.packet?.assets||{}).map(a=>a.hash));
     for(const [hash,id] of Object.entries(body)){if(!known.has(hash)||!/^\d{1,20}$/.test(String(id)))throw Error('Hash/AssetId inválido');mapping[hash]=String(id);}
     await commit({...state,mapping,revision:state.revision+1});return;
    }
    const p=validate(body);
    for(const a of Object.values(p.assets)){
     if(!a.bytes)throw Error('Exportación sin PNG originales');
     const buffer=Buffer.from(a.bytes);const hash=createHash('sha256').update(buffer).digest('hex');
     await writeFile(join(directory,'assets',hash+'.png'),buffer);delete a.bytes;a.hash=hash;a.file=hash+'.png';
    }
    // Retain image mappings by content hash across imports and changed layer IDs.
    const packet={schema:1,sourceId:p.sourceId,name:p.name,width:p.width,height:p.height,nodes:p.nodes,assets:p.assets,warnings:Array.isArray(p.warnings)?p.warnings.slice(0,1500).map(String):[]};
    await commit({...state,packet,revision:state.revision+1});
   });queue=work.catch(()=>{});await work;
   send(200,{ok:true,revision:state.revision,assetDirectory:join(directory,'assets')});
  }catch(e){send(400,{error:e instanceof SyntaxError?'JSON inválido':String(e.message||e)});}
 });
 server.requestTimeout=30000;server.headersTimeout=15000;
 return {server,token,directory};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const bridge=await createBridge();bridge.server.listen(38474,'127.0.0.1',()=>{
  console.log('UI Bridge local: http://localhost:38474');console.log('Token de esta sesión (solo plugins locales): '+bridge.token);console.log('Ctrl+C para detener. Sin conexiones cloud ni carga automática de assets.');
 });
}
