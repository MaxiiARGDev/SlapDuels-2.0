figma.showUI(__html__, {width:430,height:540, themeColors:true});
let exporting=false;
figma.ui.onmessage=async msg=>{
 if(msg.type!=='export'||exporting)return;
 exporting=true;
 try {
  const selected=figma.currentPage.selection;
  if(selected.length!==1)throw Error('Seleccioná exactamente un Frame o componente');
  const root=selected[0];
  let key=root.getPluginData('SlapDuelsBridgeSource');
  if(!key){key='design-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);root.setPluginData('SlapDuelsBridgeSource',key);}
  const packet=await exportSelection(root,(figma.fileKey||key)+':'+root.id,n=>n.exportAsync({format:'PNG',constraint:{type:'SCALE',value:2}}));
  figma.ui.postMessage({type:'exported',packet});
 } catch(e){figma.ui.postMessage({type:'error',message:String(e.message||e)});}
 finally{exporting=false;}
};
