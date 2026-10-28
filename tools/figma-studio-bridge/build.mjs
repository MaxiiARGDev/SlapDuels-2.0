import {readFile,writeFile} from 'node:fs/promises';
const base=new URL('./',import.meta.url);
const helpers=await readFile(new URL('figma/exporter.mjs',base),'utf8');
const main=await readFile(new URL('figma/main.js',base),'utf8');
await writeFile(new URL('figma/code.js',base),helpers.replace(/^export /gm,'')+'\n'+main);
console.log('Figma code.js listo. Importar figma/manifest.json como plugin de desarrollo.');
