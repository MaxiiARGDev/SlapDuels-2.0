export const classes=new Set(['Frame','TextLabel','TextButton','ImageLabel','ImageButton','ScrollingFrame']);
export function validate(p) {
 const check=(yes,message)=>{if(!yes)throw Error(message);};
 const num=(v,min,max)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max;
 const string=(v,max)=>typeof v==='string'&&v.length<=max;
 const color=v=>Array.isArray(v)&&v.length===3&&v.every(x=>num(x,0,1));
 check(p&&p.schema===1,'Schema incompatible');
 check(string(p.sourceId,200)&&p.sourceId.length>0,'sourceId inválido');
 check(string(p.name,100),'Nombre inválido');
 check(num(p.width,1,16000)&&num(p.height,1,16000),'Tamaño inválido');
 check(Array.isArray(p.nodes)&&p.nodes.length>0&&p.nodes.length<=1500,'Cantidad de capas inválida');
 const seen=new Set();const depths=new Map();let roots=0;
 for(const n of p.nodes){
  check(n&&string(n.id,200)&&n.id.length>0&&!seen.has(n.id),'ID duplicado o inválido');
  check(classes.has(n.class)&&string(n.name,100),'Clase/nombre inválido');
  if(n.parent===null){roots++;depths.set(n.id,0);}else{check(seen.has(n.parent),'Padre ausente/desordenado');depths.set(n.id,depths.get(n.parent)+1);}
  check(depths.get(n.id)<=40,'Jerarquía demasiado profunda');
  for(const k of ['x','y'])check(num(n[k],-100,100),'Posición inválida');
  for(const k of ['w','h'])check(num(n[k],0,100),'Tamaño relativo inválido');
  check(num(n.rotation,-360,360)&&num(n.opacity,0,1)&&num(n.fillOpacity,0,1)&&color(n.color),'Estilo inválido');
  check(num(n.radius,0,16000),'Radio inválido');
  if(n.text!==undefined)check(string(n.text,10000)&&num(n.textSize,1,1000)&&color(n.textColor)&&num(n.textOpacity,0,1)&&['Left','Center','Right'].includes(n.align)&&string(n.font,50),'Texto inválido');
  if(n.stroke)check(color(n.stroke.color)&&num(n.stroke.width,0,100)&&num(n.stroke.opacity,0,1),'Borde inválido');
  if(n.assetId!==undefined)check(/^\d{1,20}$/.test(n.assetId),'AssetId inválido');
  if(n.asset!==undefined)check(string(n.asset,200),'Referencia de imagen inválida');
  check(!seen.has(n.id),'ID duplicado');seen.add(n.id);
 }
 check(roots===1&&p.nodes[0].parent===null,'Debe existir una sola raíz');
 check(p.assets&&typeof p.assets==='object'&&!Array.isArray(p.assets),'Assets inválidos');
 check(Object.keys(p.assets).length<=150,'Máximo 150 PNG por exportación');
 let bytes=0;
 for(const [id,a] of Object.entries(p.assets)){
  check(seen.has(id)&&a&&string(a.name,100),'Asset sin capa');
  if(a.bytes!==undefined){check(Array.isArray(a.bytes)&&a.bytes.length<=8*1024*1024&&a.bytes.every(v=>Number.isInteger(v)&&v>=0&&v<=255),'PNG inválido');
   check([137,80,78,71,13,10,26,10].every((v,i)=>a.bytes[i]===v),'Firma PNG inválida');bytes+=a.bytes.length;}
 }
 check(bytes<=20*1024*1024,'Máximo 20 MB de PNG por exportación');
 for(const n of p.nodes)if(n.asset)check(Object.hasOwn(p.assets,n.asset),'PNG referenciado no encontrado');
 return p;
}
