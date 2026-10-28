// Pure helpers are also exercised outside Figma.
export function cleanName(name) {
  return name.replace(/\[(?:button|scroll|raster|dynamic|font=[\w]+|asset=\d+)\]/gi, '').trim().slice(0, 100) || 'Element';
}
export function rgb(c) { return [c.r, c.g, c.b]; }
export function tag(name, value) { return name.toLowerCase().includes('[' + value + ']'); }
export function classify(n) {
  if (tag(n.name,'button')) return 'TextButton';
  if (tag(n.name,'scroll')) return 'ScrollingFrame';
  if (n.type === 'TEXT') return 'TextLabel';
  return 'Frame';
}
export async function exportSelection(root, sourceId, rasterize) {
  const warnings = [], assets = {}, nodes = [];
  async function visit(n, parentId, pw, ph, depth) {
    if (n.visible === false) return;
    if (nodes.length >= 1500 || depth > 40) throw Error('Máximo: 1500 capas / 40 niveles');
    const fills = Array.isArray(n.fills) ? n.fills.filter(f => f.visible !== false) : [];
    const effects = (n.effects || []).filter(e => e.visible !== false);
    const dynamic = tag(n.name,'dynamic');
    let raster = tag(n.name,'raster') || ['VECTOR','BOOLEAN_OPERATION','STAR','POLYGON','LINE','ELLIPSE'].includes(n.type) || fills.some(f => f.type === 'IMAGE');
    if (effects.length || fills.some(f => !['SOLID','IMAGE'].includes(f.type)) || fills.length > 1) {
      if (!dynamic && !tag(n.name,'button') && !tag(n.name,'scroll')) raster = true;
      else warnings.push(n.name + ': efectos/rellenos complejos aproximados; mantenido editable');
    }
    if (n.isMask) warnings.push(n.name + ': máscara no convertida; rasterizá su contenedor con [raster]');
    if (n.layoutMode && n.layoutMode !== 'NONE') warnings.push(n.name + ': Auto Layout exportado como geometría resuelta, sin reglas dinámicas');
    if (n.rotation) warnings.push(n.name + ': rotación convertida; revisar pivote visual');
    const row = {id:n.id, parent:parentId, name:cleanName(n.name), class:raster?(tag(n.name,'button')?'ImageButton':'ImageLabel'):classify(n),
      x:parentId ? n.x / pw : 0, y:parentId ? n.y / ph : 0,
      w:parentId ? n.width / pw : 1, h:parentId ? n.height / ph : 1,
      rotation:-(n.rotation || 0), opacity:n.opacity ?? 1, clip:!!n.clipsContent,
      color:[1,1,1], fillOpacity:0, radius:typeof n.cornerRadius === 'number'?n.cornerRadius:0};
    const solid = fills.find(f=>f.type==='SOLID');
    if (solid) { row.color=rgb(solid.color); row.fillOpacity=solid.opacity ?? 1; }
    const stroke=Array.isArray(n.strokes) && n.strokes.find(f=>f.type==='SOLID' && f.visible!==false);
    if (stroke && typeof n.strokeWeight==='number') row.stroke={color:rgb(stroke.color),width:n.strokeWeight,opacity:stroke.opacity??1};
    if (raster) {
      const bytes=await rasterize(n); assets[n.id]={name:row.name,bytes:Array.from(bytes)};row.asset=n.id;row.fillOpacity=0;row.opacity=1;
    } else if (n.type==='TEXT') {
      row.text=n.characters;row.textSize=typeof n.fontSize==='number'?n.fontSize:18;
      row.textColor=solid?rgb(solid.color):[1,1,1];row.fillOpacity=0;
      row.font=(n.name.match(/\[font=(\w+)\]/i)||[])[1]||'Gotham';
      row.align=n.textAlignHorizontal==='CENTER'?'Center':n.textAlignHorizontal==='RIGHT'?'Right':'Left';
      row.textOpacity=(solid?.opacity??1)*(n.opacity??1);
      if (typeof n.fontName !== 'object' || !['Arial','Gotham','Roboto','Source Sans Pro'].includes(n.fontName.family)) warnings.push(n.name+': fuente aproximada; usá [font=EnumFont] o [raster]');
      if (typeof n.fontSize!=='number') warnings.push(n.name+': texto con estilos mezclados simplificado');
    }
    const explicit=n.name.match(/\[asset=(\d+)\]/i);if(explicit){row.assetId=explicit[1];delete row.asset;delete assets[n.id];row.class=tag(n.name,'button')?'ImageButton':'ImageLabel';raster=true;}
    if (raster && 'children' in n && n.children.length) warnings.push(n.name+': contenedor rasterizado con sus hijos; separá cualquier texto dinámico que deba seguir editable');
    if ((n.opacity??1)!==1 && 'children' in n) warnings.push(n.name+': opacidad de grupo aplicada solo al fondo; revisar hijos');
    nodes.push(row);
    if (!raster && 'children' in n) for(const child of n.children) await visit(child,n.id,Math.max(1,n.width),Math.max(1,n.height),depth+1);
  }
  if (!root || !(root.width>0 && root.height>0)) throw Error('Seleccioná un Frame con tamaño válido');
  await visit(root,null,root.width,root.height,0);
  return {schema:1,sourceId,name:cleanName(root.name),width:root.width,height:root.height,nodes,assets,warnings};
}
